# Deploying Aluni (GCP)

One Google Compute Engine VM running everything through Kamal 2: web (Puma), worker (Sidekiq), Postgres 16, Redis 7, kamal-proxy and a Cloudflare Tunnel. Images live in Artifact Registry. Every push to `main` deploys from GitHub Actions without any stored Google key. Nothing on the VM is reachable from the internet except through Cloudflare (HTTP) and Google IAP (SSH).

The hackathon project currently runs on GCP Free Trial credits, with a USD 50 budget alert. Cloudflare is on the Free plan.

## What runs where

```
visitor ──HTTPS──▶ Cloudflare (DNS + TLS, aluni.us)
                        │ Cloudflare Tunnel (outbound from the VM)
                        ▼
GCE VM aluni-vm (us-central1-a, e2-medium, Ubuntu 24.04 amd64, 30 GB disk, 4 GB swap)
  ├─ aluni-tunnel    cloudflared → http://kamal-proxy:80
  ├─ kamal-proxy     bound to 127.0.0.1 on the host
  ├─ aluni-web       Puma
  ├─ aluni-worker    Sidekiq
  ├─ aluni-db        Postgres 16 (127.0.0.1:5432; app connects as aluni_app, not a superuser)
  └─ aluni-redis     Redis 7 (password, noeviction)

GitHub Actions ──OIDC──▶ Workload Identity Federation ──▶ SA github-deployer
               ──SSH over IAP──▶ deploy@aluni-vm
               ──push──▶ us-central1-docker.pkg.dev/astromichis-aluni/aluni/aluni
```

| Piece | Setting |
|---|---|
| GCP project | `astromichis-aluni` |
| VM service account | `aluni-runtime`, which has only `roles/aiplatform.user` (Gemini on Vertex AI) with the `cloud-platform` scope. The default Compute service account is disabled. |
| Firewall | Only `allow-ssh-from-iap` (tcp:22 from `35.235.240.0/20`). There are no 80/443 rules: ingress is the tunnel. |
| SSH user | `deploy` (Docker group, key-only). It has one key per person and one for CI. |
| Registry | Artifact Registry repo `aluni` (us-central1). The cleanup policy keeps the last 5 images and deletes images older than 7 days. |
| DNS | `aluni.us` is registered at Porkbun with Cloudflare nameservers. Tunnel routes: `aluni.us`, `www.aluni.us` → `http://kamal-proxy:80`. |
| Uploads | Volume `aluni_storage` on the VM (`ACTIVE_STORAGE_SERVICE=local`). |
| Backups | **None off the VM** (`KAMAL_BACKUP=0`, no R2). Take a disk snapshot before anything important (see below). |
| Gemini | Vertex AI (`GEMINI_BACKEND=vertex`). It uses the VM's service account and needs no API key. It is paused until resumed with the Platform switch. |

`config/deploy.yml` still defaults to the original Oracle + R2 setup (`KAMAL_BACKUP=1`, `ACTIVE_STORAGE_SERVICE=cloudflare_r2`, `GEMINI_BACKEND=api_key`). The GCP values come from the environment: the deploy workflow sets them, and so does a local `.env.gcp` for manual deploys.

## Deploying

### Automatic (normal path)

Every push to `main` (except docs-only changes) runs **Actions → Deploy** (`.github/workflows/deploy.yml`):

1. GitHub issues an OIDC token. GCP's Workload Identity Federation (pool `github`, provider `aluni-repo`) accepts it **only for this repository (matched by numeric id, so it survives a transfer) on `refs/heads/main`**. The runner then acts as `github-deployer`, which can only push to Artifact Registry, open IAP tunnels and read the VM.
2. The runner SSHes to the VM through IAP with the CI key, and the VM's host key is pinned.
3. It mints a one-hour registry token and runs `kamal deploy`. The image is built **on the VM**, which keeps the Rust build cache warm. The `pre-deploy` hook runs `db:prepare`.

The deploy runs in parallel with CI and does not wait for tests. Kamal only switches traffic once the new container passes `/up`, so a version that does not boot never replaces the running one. A typical deploy takes about 3 minutes.

### Manual (from a laptop)

You need gcloud logged in to an account with access to the project, a personal key added to `deploy@aluni-vm`, Ruby from `mise`, and `gem install kamal` (the version in `Gemfile.lock`). The app's own gems are not needed: the image is built on the VM.

Add an SSH host entry so Kamal and the remote Docker builder go through IAP:

```
Host aluni-vm
  User deploy
  IdentityFile ~/.ssh/<your key>
  ProxyCommand gcloud compute start-iap-tunnel aluni-vm 22 --listen-on-stdin --zone=us-central1-a --project=astromichis-aluni
```

Export the same non-secret values the workflow sets (see `env:` in `.github/workflows/deploy.yml`), the secrets below, and `KAMAL_REGISTRY_PASSWORD=$(gcloud auth print-access-token)`, then run:

```sh
kamal deploy
```

Keep these in a git-ignored file (any `/.env*` is ignored) and source it before running Kamal.

## Secrets

Secret values are never stored in the repo. `.kamal/secrets` only maps names. The values live in the GitHub `production` environment (restricted to `main`) and, for manual deploys, in each operator's local secret store.

| Secret | What it is |
|---|---|
| `RAILS_MASTER_KEY` | Decrypts `config/credentials.yml.enc` (`secret_key_base`, data source logins) |
| `POSTGRES_PASSWORD`, `APP_DB_PASSWORD` | Postgres superuser (accessory only) and the app role |
| `REDIS_PASSWORD` | Redis `requirepass` |
| `SIDEKIQ_WEB_USERNAME`, `SIDEKIQ_WEB_PASSWORD` | Basic auth for `/sidekiq` |
| `TUNNEL_TOKEN` | Cloudflare Tunnel connector token (about 180 characters) |
| `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, `..._DETERMINISTIC_KEY`, `..._KEY_DERIVATION_SALT` | Active Record encryption. The production credentials do not have them. **If these are lost, encrypted columns cannot be read.** Keep an offline copy. |
| `KAMAL_SSH_KEY` (CI only) | Private key of the CI entry on `deploy@aluni-vm` |
| `KAMAL_KNOWN_HOSTS` (CI only) | Pinned host key line for `aluni-vm` |

To rotate one, update the value in GitHub (Settings → Environments → production) and in the local store, then deploy. For the tunnel token: in Cloudflare, Tunnels → aluni → Rotate token, save it, then deploy.

## Operating

Run these after loading the environment:

```sh
ssh aluni-vm                                          # shell on the VM (over IAP)
kamal logs                                            # follow app logs
kamal console                                         # rails console
kamal app exec --reuse "bin/rails platform:status"    # which services are paused
```

**Platform switch (emergency brake).** **Actions → Platform switch → Run workflow** works from the GitHub phone app. Use `status` to check, `pause_all` if anything starts spending, and `resume` + a service only after its credentials and a budget limit are in place. `platform:bootstrap` paused cron, gemini, mail and push on the first deploy.

**Snapshot before a demo.** This is the only backup of the database and uploads:

```sh
gcloud compute disks snapshot aluni-vm --zone=us-central1-a --project=astromichis-aluni --snapshot-names=aluni-$(date +%Y%m%d-%H%M)
```

## First deploy to a new server

The `pre-deploy` hook runs migrations before Kamal has booted the accessories or written the env files, so it fails on an empty server. Run the first deploy by hand, once:

```sh
kamal proxy boot_config set --publish-host-ip=127.0.0.1   # once per server
kamal accessory boot all
kamal deploy --skip-hooks
kamal app exec --primary --reuse "bin/rails db:prepare"
kamal app exec --primary --reuse --roles=web "bin/rails platform:bootstrap"
```

After that, `kamal deploy` (and the workflow) work normally.

**Preparing the VM** (Ubuntu 24.04):

- The `deploy` user comes from the instance `ssh-keys` metadata (`deploy:<public key>`).
- `apt install docker.io docker-buildx` and `usermod -aG docker deploy`.
- Add a 4 GB swapfile; the Rust build needs it on 4 GB of RAM.
- Delete the default `default-allow-ssh` / `default-allow-rdp` firewall rules and add only the IAP range.

## If the VM is lost

1. Create a VM with the same name and zone, attached to the `aluni-runtime` service account with the `cloud-platform` scope.
2. Repeat the VM preparation and the first deploy.
3. Restore from the latest disk snapshot if there is one. Otherwise the database starts empty.

DNS and the tunnel do not change, because the tunnel token moves with the deploy.

## Gemini on Vertex AI

`GEMINI_BACKEND=vertex` makes `Gemini::Client` call Vertex AI with a token from the GCE metadata server (`Gemini::VertexToken`), so production holds no Gemini key and usage bills to the GCP project. Before turning it on with the Platform switch:

1. Set a requests-per-minute quota cap on Vertex AI for the project.
2. After the first real use, check Billing → Reports that Vertex AI usage is drawn from credits.

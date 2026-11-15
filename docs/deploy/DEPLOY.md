# Deploying Aluni for $0

One Oracle Cloud Always Free Ampere A1 VM (4 OCPU / 24 GB available; the config budgets for 2 OCPU / 12 GB), images in GitHub Container Registry, secrets in the GitHub `production` environment, ingress through a Cloudflare Tunnel (no open inbound port), SSH only over Tailscale. Falls back to any 4 GB+ amd64 VPS by changing `KAMAL_HOST` and `KAMAL_ARCH`.

Steps marked **You** need accounts or secrets Claude Code must never see. Steps marked **Claude Code** can be pasted as prompts.

## What you get

web (Puma, 3 threads) + worker (Sidekiq, 3 threads) + Postgres 16 (1 GB shared buffers, least-privilege app role) + Redis 7 (256 MB, noeviction, password) + nightly GPG-encrypted pg_dump to R2 (14 days) + cloudflared. Migrations run once per deploy. Everything that costs money starts paused (`platform:bootstrap`).

## Setup

1. **Accounts and two-factor (You).** GitHub (private repo, 2FA), Oracle Cloud (Always Free), Cloudflare (the aluni.us zone, R2), Tailscale, Apple Developer and Google Play when the shells ship. Turn on 2FA everywhere.
2. **Keys and secrets (You).** Generate and store offline: `RAILS_MASTER_KEY` (from `config/master.key`), `POSTGRES_PASSWORD`, `APP_DB_PASSWORD`, `REDIS_PASSWORD`, `BACKUP_PASSPHRASE` (without it backups cannot be restored), `SIDEKIQ_WEB_USERNAME` / `SIDEKIQ_WEB_PASSWORD` (long random), an SSH key pair for the `deploy` user (`KAMAL_SSH_KEY`), R2 API tokens (`S3_ACCESS_KEY_ID` / `S3_SECRET_ACCESS_KEY`, `R2_ACCOUNT_ID`).
3. **Create the VM (You).** Ubuntu 24.04 arm64 (Ampere A1). Note its Tailscale IP as `KAMAL_HOST`.
4. **Harden the server (You, with Claude Code's script).** Create the `deploy` user with the SSH key, disable password SSH, `ufw` default deny inbound, install Docker, let `deploy` use Docker. Prompt: "Write the server hardening script for docs/deploy/DEPLOY.md step 4 for Ubuntu 24.04 arm64."
5. **Tailscale lock-down (You).** Install Tailscale on the VM; SSH only over the tailnet (`ufw` allows 22 on `tailscale0` only). Optional: an OAuth client with workload identity for GitHub Actions (`TS_OAUTH_CLIENT_ID`, `TS_AUDIENCE`, tag `tag:ci`); until then the deploy workflow skips the tailnet step and `KAMAL_HOST` must be reachable from the runner.
6. **Cloudflare (You).** Zero Trust > Networks > Tunnels: create a tunnel, copy its token (`TUNNEL_TOKEN`), map `aluni.us` and `www.aluni.us` to `http://kamal-proxy:80`. Create the R2 buckets `aluni` (uploads) and `aluni-backups`. Boot kamal-proxy bound to localhost once: `bin/kamal proxy boot_config set --publish-host-ip=127.0.0.1 && bin/kamal proxy reboot`.
7. **Production credentials (You).** `mise exec -- bin/rails credentials:edit --environment production` (or the shared file): `secret_key_base`, `active_record_encryption.*` (`bin/rails db:encryption:init`), `redis.url`, `r2.*`, `mailer.from`, `smtp.*` (Resend or Brevo free tier), `gemini.api_key` when wanted, `web_push.*` (`bin/rails web_push:vapid_keys`), `action_push_native.*` and `native_app.*` when the stores exist.
8. **GitHub (You).** Create the `production` environment limited to `main` and `v*` tags; add the secrets from steps 2, 5, 6 plus `KAMAL_KNOWN_HOSTS` (`ssh-keyscan <host>` output) and the variables `KAMAL_SSH_USER`, `KAMAL_ARCH`, `KAMAL_TUNNEL`, `SIGNUPS_ENABLED`, `PLATFORM_PAUSE_ALL`. Allow Actions to write packages.
9. **Validate the config (Claude Code).** `bin/kamal config` with placeholder ENV exported; `docker build .` locally (arm64) to prove the Rust toolchain and the gem layer build.
10. **First deploy (You).** Run the Deploy workflow (or `git tag v2026.11.1 && git push --tags`). The first remote build compiles crates and takes several minutes; later builds hit the layer cache. Then `bin/kamal app exec --reuse "bin/rails platform:bootstrap"` pauses cron, gemini, mail and push.
11. **Check (You).** `https://aluni.us` renders the site; `https://aluni.us/up` is 200; `bin/kamal logs`; Sidekiq Web at `https://aluni.us/sidekiq` with the basic-auth pair (only if `SIDEKIQ_WEB_*` are set).
12. **Restore drill (You).** After the first nightly backup: `bin/kamal accessory exec backup "sh restore.sh"` into a scratch database, confirm tables and counts. Do it once before trusting the backups.

## Security model

No inbound port but Tailscale SSH; TLS at Cloudflare; the app connects to Postgres as `aluni_app` (no superuser, owns only its database); Redis needs a password; secrets live only in GitHub environment secrets and the deploy shell; the image has no master key (assets precompile with `SECRET_KEY_BASE_DUMMY`); `force_ssl`, CSP with nonces, Rack::Attack, Active Record encryption with a boot guard, `Vips.block_untrusted`; passkeys only, so there is no password database to leak.

## Turning services on, one by one

```
bin/kamal app exec --reuse "bin/rails platform:status"
bin/kamal app exec --reuse "bin/rails 'platform:resume[mail]'"      # after SMTP credentials and DNS records
bin/kamal app exec --reuse "bin/rails 'platform:resume[cron]'"      # after the first deploy is stable
bin/kamal app exec --reuse "bin/rails 'platform:resume[gemini]'"    # after gemini.api_key and a budget alert; the onboarding chat answers with continuation lines until then
bin/kamal app exec --reuse "bin/rails 'platform:resume[push]'"      # after APNs/FCM credentials
```

Or the Platform switch GitHub workflow (works from the phone). `PLATFORM_PAUSE_ALL=1` in `config/deploy.yml` env plus a deploy pauses everything even with the database down.

## Before a demo

1. `gemini.api_key` in the production credentials and `platform:resume[gemini]` (above); without it Aluni only says her continuation lines.
2. `NATIVE_WEB_ACCESS` defaults to on, so sign-in, the onboarding chat and `/app` work in any current browser; set it to `0` only to close the web and keep the shells.
3. Passkeys and the share-location button need a secure context: the production domain, or `localhost` in development.
4. Open the landing page, wait for Aluni to walk in, run the sign-up and a full onboarding in English and in Spanish, refresh once mid-way to see the transcript resume.

## Keeping it running

| When | What |
|---|---|
| Weekly | Dependabot PRs (bundler, cargo, actions); the security workflow (brakeman, bundler-audit, cargo audit) |
| Monthly | `bin/kamal app exec --reuse "bin/rails platform:status"`, disk usage, backup listing in R2, `docker system prune` on the VM |
| Quarterly | Restore drill; rotate `REDIS_PASSWORD` and `SIDEKIQ_WEB_PASSWORD`; review Cloudflare IP ranges in `TRUSTED_PROXIES`; bump base images (`postgres:16`, `redis:7`, `cloudflared`) |
| Always | Keep used memory above ~2.4 GB on Oracle so the VM is not reclaimed as idle; never use a free hosted Redis with Sidekiq (polling exhausts the quota) |

## If the VM is lost

Create a new VM (steps 3 to 6), set the new `KAMAL_HOST`, deploy, then `bin/kamal accessory exec backup "sh restore.sh"` with the `BACKUP_PASSPHRASE`. Uploads live in R2 and survive. DNS does not change (the tunnel moves with the token).

## Fallback: a cheap VPS

Any 4 GB+ amd64 VPS: set `KAMAL_ARCH=amd64`, `KAMAL_HOST`, and either keep the tunnel (`KAMAL_TUNNEL=1`) or set `KAMAL_TUNNEL=0` with a Cloudflare Origin certificate in `CERTIFICATE_PEM` / `PRIVATE_KEY_PEM` and firewall 80/443 to Cloudflare's ranges.

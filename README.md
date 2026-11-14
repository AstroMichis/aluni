# Aluni

An open source tool for people, not for passwords. The site at aluni.us explains it; the iOS and Android apps are where it is used, with passkeys instead of accounts to remember.

## Stack

Rails 8.1 on Ruby 4.0.8, PostgreSQL 16, Redis 7 + Sidekiq 8, Hotwire with pure CSS over importmap (no node), Rails built-in sessions with the webauthn gem (passkeys), Hotwire Native shells (`ios/`, `android/`), a Rust extension for heavy service steps (`vendor/gems/aluni_core`), Kamal 2 deploys to an Oracle Always Free VM.

## Getting started

```sh
mise install                          # Ruby from mise.toml
mise exec -- bin/setup --skip-server  # bundle, compile the Rust extension, create the databases
```

Run the web process and the worker (two terminals, or `foreman start -f Procfile.dev`):

```sh
mise exec -- bin/rails server -b 0.0.0.0 -p 3000
mise exec -- bundle exec sidekiq -C config/sidekiq.yml
```

Open http://localhost:3000. Passkeys need a secure context: use `localhost`, not a LAN name (`docs/AUTH.md`). In development `NATIVE_WEB_ACCESS` defaults to on, so sign-in and `/app` also work in a desktop browser.

## Tests and checks

```sh
mise exec -- bundle exec rspec        # request specs render pages; system specs use Cuprite (Chrome)
mise exec -- bin/rubocop
mise exec -- bin/brakeman --no-pager
mise exec -- bin/rails core:check     # cargo fmt, clippy, cargo test
```

## Documentation

`CLAUDE.md` is the map. Start with `docs/AUTH.md`, `docs/NATIVE.md`, `docs/RAILS_PATTERNS.md` and `docs/deploy/DEPLOY.md`.

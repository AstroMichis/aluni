# Rust for service logic

Heavy, CPU-bound steps of a service can move to Rust. The shape is **an in-process native extension** (`vendor/gems/aluni_core`, magnus on rb-sys) called from ordinary Ruby service objects. Nothing else in the app knows Rust exists.

Verified on this machine on 2026-11-14: Ruby 4.0.8, Rust 1.92.0 (Homebrew cargo, no rustup), magnus 0.9.3, rb-sys 0.9.130 with the `stable-api-compiled-fallback` feature compiles and runs (`bundle gem --ext=rust` smoke test, then the real gem).

## Layout

```
rust-toolchain.toml                 # channel 1.92.0, profile minimal, clippy + rustfmt (rustup honours it; Homebrew cargo ignores it)
vendor/gems/aluni_core/
  Cargo.toml                        # workspace root -> ext/aluni_core
  Cargo.lock                        # committed
  aluni_core.gemspec                # extensions = ext/aluni_core/extconf.rb, depends on rb_sys
  Rakefile                          # RbSys::ExtensionTask (compile)
  ext/aluni_core/{Cargo.toml,extconf.rb,build.rs,src/lib.rs}
  lib/aluni_core.rb, lib/aluni_core/version.rb
app/services/core/*_service.rb      # the only callers of AluniCore
lib/tasks/core.rake                 # core:compile, core:check
.claude/rules/rust.md               # path-scoped rules
```

`Gemfile`: `gem "rb_sys", "~> 0.9"` and `gem "aluni_core", path: "vendor/gems/aluni_core"`.

## Rules

- Rust takes and returns plain data (strings, integers, byte arrays, arrays and hashes of those). Large structures cross as bytes or JSON strings.
- Rust never opens a database connection, never reads credentials, never renders. Ruby orchestrates, validates, persists, translates.
- No `unsafe` without a reviewed comment; no `unwrap()` on data from Ruby; return `Err(magnus::Error)` (magnus turns it into a Ruby exception, which the Ruby service rescues into a `Failure`).
- Release the GVL around pure-Rust sections longer than a few milliseconds that touch no Ruby objects.
- Move a step to Rust only after a `benchmark-ips` measurement shows the Ruby version is the bottleneck; keep the Ruby version as the spec oracle until the Rust one is proven.
- Rust unit tests next to the code (`cargo test`, with `rb_sys_test_helpers` booting a VM); behaviour tests in RSpec against the Ruby service (`spec/services/core`).

## Dev loop

```sh
mise exec -- bin/rails core:compile   # after editing Rust; Bundler does not rebuild a path gem's extension on its own
mise exec -- bin/rails core:check     # cargo fmt --check, clippy -D warnings, cargo test (runs cargo unbundled, RUBY pinned to the project Ruby)
mise exec -- bundle exec rspec spec/services/core
```

`bin/setup` compiles the extension after `bundle install`. The compiled `.bundle`/`.so` and `target/` are git-ignored.

## CI and Docker

`.github/workflows/ci.yml`: `rustup show` installs the channel from `rust-toolchain.toml` (runners ship rustup), then `bin/rails core:compile`, `cargo test`, `cargo fmt --check`, `cargo clippy -D warnings`, `cargo audit` in the weekly security job. No crate cache yet; add `actions/cache` pinned by SHA on `~/.cargo/registry` and `vendor/gems/aluni_core/target` keyed on `Cargo.lock` when build time matters.

`Dockerfile` build stage: installs rustup with `--default-toolchain none`, `rustup show` picks the pinned channel, `COPY vendor/gems` before `bundle install` so the extension compiles in the gem layer with a cargo registry cache mount. The runtime stage copies the compiled extension with the gems and has no Rust. Kamal builds on the arm64 VM (`KAMAL_BUILDER_REMOTE`), so the compile never runs under QEMU.

## When an extension is the wrong tool

A separate Rust service (axum as a Kamal accessory on the private Docker network, called through a Faraday client with `Platform::FaradayPauseGuard`) fits work that must run outside the Rails process lifecycle: long-running or streaming computations, a different scaling profile, memory you do not want inside Puma. A Rust CLI invoked with `Open3.capture3` from a Sidekiq job fits batch work where process isolation is worth the spawn cost. Both keep the same rules: no database, no credentials, plain data in and out, a pause switch.

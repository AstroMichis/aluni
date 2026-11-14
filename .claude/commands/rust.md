# /rust -- Move a service step to the Rust extension

You are adding or changing a Rust function in `vendor/gems/aluni_core` for Aluni. The request is: $ARGUMENTS

## Before writing code:

1. Read `docs/RUST.md` and `.claude/rules/rust.md`
2. Read `vendor/gems/aluni_core/ext/aluni_core/src/lib.rs` and `lib/aluni_core.rb` (the soft-fail loader and the `FUNCTIONS` list)
3. Read `app/services/core/normalize_service.rb` and `spec/services/core/normalize_service_spec.rb`
4. Read `lib/tasks/core.rake`

## Steps

1. **Measure first.** Write or keep the Ruby version of the step in a service and benchmark it (`benchmark-ips` in a scratch script or spec). Move it only if it is the bottleneck.
2. **Write the Rust function** in `ext/aluni_core/src/lib.rs`: plain inputs and outputs (`String`, integers, `Vec<u8>`, `Vec<...>`, hashes of those; JSON strings for big structures), `Result<T, magnus::Error>`, errors built from a Ruby exception class (`ruby.exception_arg_error()`), no `unwrap()` on Ruby data, no `unsafe` without a reviewed comment. Register it in `init` with `define_singleton_method("name", function!(name, arity))`.
3. **Add the name to `FUNCTIONS`** in `lib/aluni_core.rb` so the not-compiled stub raises `AluniCore::NotCompiled` for it too.
4. **Write a Rust unit test** next to the function (`#[ruby_test]` from `rb_sys_test_helpers`).
5. **Wrap it in a Ruby service** in `app/services/core/<name>_service.rb`: `ApplicationService`, `Success(AluniCore.name(...))`, `rescue ArgumentError, RuntimeError, AluniCore::Error => e` into `Failure(code: :core_error, message:)`. Keep the Ruby implementation as the spec oracle until the Rust one is proven.
6. **RSpec against the service** in `spec/services/core/`.
7. **Compile and check**: `mise exec -- bin/rails core:compile`, `mise exec -- bin/rails core:check` (fmt, clippy -D warnings, cargo test), `mise exec -- bundle exec rspec spec/services/core`.
8. **Release the GVL** around pure-Rust sections longer than a few milliseconds that touch no Ruby objects (check the current magnus API for a without-GVL helper before using the raw `rb_sys` binding).

## Rules

- Rust never opens a database connection, never reads credentials, never renders
- Only `app/services/core/*` call `AluniCore`; the rest of the app sees a service object
- Commit `Cargo.lock`; never commit `target/` or the compiled `.bundle`/`.so`
- The Docker build and CI compile through `(cd vendor/gems/aluni_core && bundle exec rake compile)`; keep that path working
- Crate updates arrive through Dependabot (cargo ecosystem); `cargo audit` runs weekly in CI

---
paths:
  - "vendor/gems/aluni_core/**"
---

# Rust extension rules (aluni_core)

- Functions take and return plain data: strings, integers, byte arrays, arrays and hashes of those. Large structures cross the boundary as bytes or JSON strings, never as Ruby object graphs.
- Rust never opens a database connection, never reads Rails credentials, never renders anything. Ruby orchestrates, validates, persists and translates.
- No `unsafe` unless a reviewed comment explains why. No `unwrap()` on data that comes from Ruby. Return `Err(magnus::Error)` built from a Ruby exception class instead of panicking.
- The Ruby-visible surface stays tiny: module functions on `AluniCore`, each wrapped by one service object in `app/services/core/`. Nothing else calls `AluniCore`.
- Move a step to Rust only after a `benchmark-ips` measurement shows the Ruby version is the bottleneck; keep the Ruby implementation as the spec oracle until the Rust one is proven.
- For CPU-bound calls longer than a few milliseconds, release the GVL around pure-Rust sections that touch no Ruby objects.
- Rust unit tests live next to the code (`cargo test`); behaviour tests live in RSpec against the Ruby service.
- After editing Rust run `bin/rails core:compile`; before claiming done run `bin/rails core:check`.

# aluni_core

The Rust extension behind Aluni's heavy service steps, built with magnus on
rb-sys and loaded in-process. Only `app/services/core/*` calls it. See
`docs/RUST.md` for the rules, the dev loop (`bin/rails core:compile`) and the
CI and Docker steps.

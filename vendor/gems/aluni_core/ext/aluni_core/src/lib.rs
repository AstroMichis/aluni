//! aluni_core: the Rust side of Aluni's service layer.
//!
//! Rules (see .claude/rules/rust.md and docs/RUST.md):
//! - Functions take and return plain data (strings, integers, byte arrays, arrays
//!   and hashes of those). Large structures cross the boundary as bytes or JSON.
//! - No database, no credentials, no rendering. Ruby orchestrates and persists.
//! - No `unsafe` without a reviewed comment; no `unwrap()` on data from Ruby;
//!   return `Err(magnus::Error)` instead of panicking.
//! - A step moves here only after a benchmark shows the Ruby version is the
//!   bottleneck; the Ruby service stays the public API and the spec oracle.
use magnus::{function, prelude::*, Error, Ruby};

/// Trims surrounding whitespace, collapses inner runs of whitespace to one
/// space and lowercases the result. Empty input is an error so callers never
/// persist an empty normalized value by accident.
fn normalize(ruby: &Ruby, input: String) -> Result<String, Error> {
    let trimmed = input.trim();
    if trimmed.is_empty() {
        return Err(Error::new(ruby.exception_arg_error(), "input is empty"));
    }
    Ok(trimmed
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .to_lowercase())
}

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let module = ruby.define_module("AluniCore")?;
    module.define_singleton_method("normalize", function!(normalize, 1))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::normalize;
    use rb_sys_test_helpers::ruby_test;

    #[ruby_test]
    fn normalizes_whitespace_and_case() {
        let ruby = magnus::Ruby::get().expect("ruby vm");
        assert_eq!(
            "hello world",
            normalize(&ruby, "  Hello   World ".to_string()).unwrap()
        );
    }

    #[ruby_test]
    fn rejects_empty_input() {
        let ruby = magnus::Ruby::get().expect("ruby vm");
        assert!(normalize(&ruby, "   ".to_string()).is_err());
    }
}

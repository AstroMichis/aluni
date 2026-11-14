# frozen_string_literal: true

require_relative "lib/aluni_core/version"

Gem::Specification.new do |spec|
  spec.name = "aluni_core"
  spec.version = AluniCore::VERSION
  spec.authors = [ "Aluni contributors" ]
  spec.summary = "Rust-backed service functions for Aluni"
  spec.description = "In-process native extension (magnus on rb-sys) called only from Ruby service objects."
  spec.homepage = "https://aluni.us"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 4.0.0"
  spec.metadata["allowed_push_host"] = "https://never.published.example"

  # A path gem inside the application; no git listing needed.
  spec.files = Dir["lib/**/*.rb", "ext/**/*.{rs,rb,toml}", "Cargo.toml", "Cargo.lock", "README.md"]
  spec.require_paths = [ "lib" ]
  spec.extensions = [ "ext/aluni_core/extconf.rb" ]

  spec.add_dependency "rb_sys", "~> 0.9.128"
end

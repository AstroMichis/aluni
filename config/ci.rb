# Run using bin/ci (Rails 8.1 local CI). Mirrors .github/workflows/ci.yml.

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"
  step "Style and tests: Rust", "bin/rails core:check"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Importmap vulnerability audit", "bin/importmap audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  step "Tests: RSpec", "bundle exec rspec"
end

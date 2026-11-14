# The Rust extension (vendor/gems/aluni_core). Bundler does not compile a path
# gem's extension on `bundle install`, and does not rebuild it when its sources
# change, so run this after cloning and after editing Rust:
#   bin/rails core:compile
# Until then the app boots with AluniCore in its "not compiled" state
# (AluniCore.compiled? == false, every call raises AluniCore::NotCompiled).
namespace :core do
  CORE_DIR = Rails.root.join("vendor/gems/aluni_core")

  desc "Compile the aluni_core Rust extension"
  task :compile do
    Dir.chdir(CORE_DIR) { sh "bundle exec rake compile" }
  end

  desc "cargo fmt --check, clippy -D warnings and cargo test for aluni_core"
  task :check do
    # cargo must not inherit Bundler's RUBYOPT (the test binary embeds a Ruby VM
    # that would then load the app Gemfile), and rb-sys must build against the
    # project Ruby, not whatever `ruby` is first in PATH.
    Dir.chdir(CORE_DIR) do
      Bundler.with_unbundled_env do
        env = { "RUBY" => RbConfig.ruby }
        sh env, "cargo fmt --all --check"
        sh env, "cargo clippy --all-targets -- -D warnings"
        sh env, "cargo test"
      end
    end
  end
end

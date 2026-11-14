# Defense in depth for uploads: refuse libvips loaders flagged as untrusted.
# Requires libvips >= 8.13 (the Dockerfile installs it).
begin
  require "vips"
  Vips.block_untrusted(true) if Vips.respond_to?(:block_untrusted)
rescue LoadError
  # libvips is not installed (e.g. local dev without `brew install vips`).
end

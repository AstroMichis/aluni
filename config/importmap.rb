# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# Three.js, vendored (vendor/javascript/three.js, r169 ESM build). Loaded lazily
# inside hero_scene_controller.js with `await import("three")`, so only pages
# that mount the controller download it and no CSP exception is needed.
pin "three", to: "three.js", preload: false
pin "@hotwired/hotwire-native-bridge", to: "@hotwired--hotwire-native-bridge.js" # @1.2.2

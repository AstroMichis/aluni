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
# Leaflet 1.9.4, vendored (vendor/javascript/leaflet.js, the dist/leaflet-src.esm.js build with its
# sourceMappingURL line removed). Loaded lazily by field_map_controller.js when the map opens.
pin "leaflet", to: "leaflet.js", preload: false
# The mascot's plain modules (character, animator, palette). Only *_controller
# files are auto-registered, so these stay modules that mascot_controller.js
# imports lazily next to Three.
pin_all_from "app/javascript/mascot", under: "mascot", preload: false
pin "@hotwired/hotwire-native-bridge", to: "@hotwired--hotwire-native-bridge.js" # @1.2.2

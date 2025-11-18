pin "application"

pin "@hotwired/stimulus", to: "@hotwired--stimulus.js" # @3.2.2
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "@hotwired/turbo-rails", to: "turbo.js"
pin "@rails/actioncable", to: "actioncable.esm.js"
pin "@rails/request.js", to: "@rails--request.js" # @0.0.8
pin "trix", to: "trix.esm.min.js" # @2.0.10
pin "@rails/actiontext", to: "actiontext.js"
pin "highlight.js", to: "highlight.js/core.js"
pin "@hotwired/hotwire-native-bridge", to: "@hotwired--hotwire-native-bridge.js" # @1.0.0

pin_all_from "app/frontend/initializers", under: "initializers"
pin_all_from "app/frontend/lib", under: "lib"
pin_all_from "app/frontend/channels", under: "channels"
pin_all_from "app/frontend/controllers", under: "controllers"
pin_all_from "app/frontend/helpers", under: "helpers"
pin_all_from "app/frontend/models", under: "models"
pin_all_from "vendor/javascript/languages", under: "languages"

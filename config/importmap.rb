# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
# Removed ActionText dependencies as we're no longer using it
# pin "trix"
# pin "@rails/actiontext", to: "actiontext.esm.js"

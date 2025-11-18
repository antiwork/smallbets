# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Vite handles CSS/JS bundling; keep app/frontend available for Importmap-only JS (e.g., Turbo/Stimulus)
Rails.application.config.assets.paths << Rails.root.join("app", "frontend")

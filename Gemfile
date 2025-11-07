source "https://rubygems.org"

git_source(:github) { |repo| "https://github.com/#{repo}.git" }
git_source(:bc)     { |repo| "https://github.com/basecamp/#{repo}" }

# Rails
gem "rails", github: "rails/rails", branch: "main"

# Drivers
gem "sqlite3", "~> 1.4"
gem "redis", "~> 4.0"

# Deployment
gem "puma", "~> 6.4"

# Jobs
gem "resque", "~> 2.6.0"
gem "resque-pool", "~> 0.7.1"
gem "resque-scheduler", "~> 4.11.0"

# Assets
gem "propshaft", github: "rails/propshaft"
gem "importmap-rails", github: "rails/importmap-rails"

# Hotwire
gem "turbo-rails", github: "hotwired/turbo-rails"
gem "stimulus-rails"

# Media handling
gem "image_processing", ">= 1.2"

# Telemetry
gem "sentry-ruby"
gem "sentry-rails"

# Other
gem "bcrypt"
gem "web-push"
gem "rqrcode"
gem "rails_autolink"
gem "geared_pagination"
gem "jbuilder"
gem "net-http-persistent"
gem "kredis"
gem "platform_agent"
gem "thruster"
gem "faraday"

group :development, :test do
  gem "debug"
  gem "rubocop-rails-omakase", require: false
  gem "faker", require: false
  gem "brakeman", require: false
end

group :test do
  gem "capybara"
  gem "mocha"
  gem "selenium-webdriver"
  gem "webmock", require: false
end

gem "dotenv", groups: [ :development, :test ]
gem "letter_opener", group: :development
gem "stringex"

gem "resend"

gem "heapy", group: :development

gem "rufus-scheduler"
gem "mailkick"

gem "rack-mini-profiler", "~> 4.0", require: false
gem "stackprof", "~> 0.2"

gem "inertia_rails", "~> 3.11"

gem "vite_rails", "~> 3.0"

gem "ruby-openai"

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby File.read(".ruby-version").strip

gem "rails", "~> 7.0.5"
gem "pg", "~> 1.1"
gem "puma", "~> 5.0"
gem "sprockets-rails", "~> 3.4"
gem "importmap-rails", "~> 1.0"
gem "turbo-rails", "~> 1.0"
gem "stimulus-rails", "~> 1.0"
gem "jbuilder", "~> 2.11"
gem "redis", "~> 4.0"
gem "bcrypt", "~> 3.1.7"
gem "tzinfo-data", "~> 1.2021", platforms: %i[mingw mswin x64_mingw jruby]
gem "bootsnap", "~> 1.10"
gem "devise", "~> 4.8"
gem "strong_password", "~> 0.0.10"
gem "friendly_id", "~> 5.4"
gem "auto_strip_attributes", "~> 2.6"
gem "flipper", "~> 0.23.0"
gem "flipper-ui", "~> 0.23.0"
gem "flipper-active_record", "~> 0.23.0"
gem "dotenv-rails", "~> 2.7"
gem "rack-cors", "~> 1.1", require: "rack/cors"
gem "octokit", "~> 4.22"
gem "jwt", "~> 2.3"
gem "postmark-rails", "~> 0.21.0"
gem "ruby-duration", "~> 3.2"
gem "sidekiq", "< 8"
gem "http", "~> 5.0"
gem "connection_pool", "~> 2.2"
gem "haikunator", "~> 1.1"
gem "semantic", "~> 1.6"
gem "sassc-rails", "~> 2.1"
gem "tailwindcss-rails", "~> 2.0"
gem "paper_trail", "~> 12.2"
gem "google-apis-androidpublisher_v3", "~> 0.16.0"
gem "googleauth", "~> 1.1"
gem "gretel", "~> 4.4"
gem "sentry-ruby", "~> 5.7"
gem "sentry-rails", "~> 5.7"
gem "google-cloud-storage", "~> 1.37"
gem "down", "~> 5.3"
gem "faraday-retry", "~> 2.0"
gem "rubyzip", "~> 2.3"
gem "requestjs-rails", "~> 0.0.9"
gem "groupdate", "~> 6.1"
gem "chartkick", "~> 4.2"
gem "pghero", "~> 3.1"
gem "aasm", "~> 5.3"
gem "after_commit_everywhere", "~> 1.2"
gem "retryable", "~> 3.0"
gem "lograge", "~> 0.12.0"
gem "ougai", "~> 2.0"
gem "amazing_print", "~> 1.4"
gem "ddtrace", "~> 1.4"
gem "dogstatsd-ruby", "~> 5.5"
gem "memery", "~> 1.4"
gem "data_migrate", "~> 8.1"
gem "device_detector", "~> 1.0"
gem "strong_migrations", "~> 1.4"
gem "fast_blank", "~> 1.0"
gem "oj", "~> 3.13"
gem "easymon", "~> 1.6"
gem "github-ds", "~> 0.5.2"
gem "pagy", "~> 6.0"
gem "view_component", "~> 2.82"
gem "activerecord_json_validator", "~> 2.1"
gem "sidekiq-cron", "~> 1.9"
gem "intercom-rails", "~> 0.4.2"
gem "google-apis-firebaseappdistribution_v1", "~> 0.1"

group :development, :test do
  gem "debug", platforms: %i[mri mingw x64_mingw]
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "pry"
  gem "brakeman", "~> 5.2", require: false
  gem "bundler-audit", "~> 0.9.1", require: false
  gem "pg_query"
  gem "prosopite"
  gem "standard", "~> 1.2", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-rspec", require: false
  gem "rubocop-performance", require: false
  gem "stateoscope"
end

group :development do
  gem "web-console"
  gem "rack-mini-profiler"
  gem "letter_opener"
  gem "letter_opener_web"
  gem "awesome_print"
  gem "annotate"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "webdrivers"
  gem "simplecov"
  gem "webmock"
end

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.1.0"

gem "rails", "~> 7.0.1"
gem "pg", "~> 1.1"
gem "puma", "~> 5.0"
gem "sprockets-rails", "~> 3.4"
gem "importmap-rails", "~> 1.0"
gem "turbo-rails", "~> 1.0"
gem "stimulus-rails", "~> 1.0"
gem "jbuilder", "~> 2.11"
gem "redis", "~> 4.0"
gem "kredis", "~> 1.0"
gem "bcrypt", "~> 3.1.7"
gem "tzinfo-data", "~> 1.2021", platforms: %i[mingw mswin x64_mingw jruby]
gem "bootsnap", "~> 1.10"
gem "sassc-rails", "~> 2.1"
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
gem "sidekiq", "~> 6.4"
gem "sidekiq-scheduler", "~> 3.1"
gem "random_name_generator", "~> 2.0"

group :development, :test do
  gem "debug", platforms: %i[mri mingw x64_mingw]
  gem "standard"
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "pry"
end

group :development do
  gem "web-console"
  gem "rack-mini-profiler"
  gem "letter_opener"
  gem "letter_opener_web"
  gem "awesome_print"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "webdrivers"
end
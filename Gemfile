source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.1.0"

gem "rails", "~> 7.0.1"
gem "sprockets-rails"
gem "pg", "~> 1.1"
gem "puma", "~> 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "jbuilder"
gem "redis", "~> 4.0"
gem "kredis"
gem "bcrypt", "~> 3.1.7"
gem "tzinfo-data", platforms: %i[mingw mswin x64_mingw jruby]
gem "bootsnap", require: false
gem "sassc-rails"
gem "devise"
gem "strong_password"

group :development, :test do
  gem "debug", platforms: %i[mri mingw x64_mingw]
  gem "standard"
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
end

group :development do
  gem "web-console"
  gem "rack-mini-profiler"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "webdrivers"
end

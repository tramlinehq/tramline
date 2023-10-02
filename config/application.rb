require_relative "boot"

require "rails/all"
require_relative "../lib/logging_extensions"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Site
  class Application < Rails::Application
    if %w[development test].include? Rails.env
      Dotenv::Railtie.load if defined? Dotenv
    end

    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"

    config.eager_load_paths << Rails.root.join("lib")
    config.active_job.queue_adapter = :sidekiq
    config.active_model.i18n_customize_full_message = true
    config.assets.css_compressor = nil
    config.middleware.insert_after ActionDispatch::Static, Rack::Deflater
    config.action_dispatch.default_headers["X-XSS-Protection"] = "1; mode=block"
    PaperTrail.config.version_limit = 10
    config.active_storage.draw_routes = false

    require "json_logger"
    config.log_formatter = LoggingExtensions.default_log_formatter
    config.logger = ActiveSupport::TaggedLogging.new(JsonLogger.new(Rails.root.join("log", "#{Rails.env}.log")))

    if ENV["RAILS_PIPELINE_ENV"].present?
      Rails.application.config.credentials.content_path =
        Rails.root.join("config/credentials/#{ENV["RAILS_PIPELINE_ENV"]}.yml.enc")
    end
  end

  require "site_extensions"
  require "site_http"
  require "site_analytics"
end

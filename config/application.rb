require_relative "boot"
require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Site
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

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

    require "logging_extensions"
    require "json_logger"
    config.log_formatter = LoggingExtensions.default_log_formatter
    config.logger = ActiveSupport::TaggedLogging.new(JsonLogger.new(Rails.root.join("log", "#{Rails.env}.log")))

    if ENV["RAILS_PIPELINE_ENV"].present?
      Rails.application.config.credentials.content_path =
        Rails.root.join("config/credentials/#{ENV["RAILS_PIPELINE_ENV"]}.yml.enc")
    end

    config.x.app_redirect = ENV["APP_REDIRECT_MAPPING_JSON"] ? JSON.parse(ENV["APP_REDIRECT_MAPPING_JSON"]) : {}
  end
end

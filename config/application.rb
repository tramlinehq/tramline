require_relative "boot"
require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

def add_dummy_gcp_config_for_demo_seed_mode
  if ENV["SEED_MODE"] == "demo"
    Rails.application.credentials.dependencies = ActiveSupport::OrderedOptions.new
    Rails.application.credentials.dependencies.gcp = ActiveSupport::OrderedOptions.new

    Rails.application.credentials.dependencies.gcp.project_id = "dummy-project-id"
    Rails.application.credentials.dependencies.gcp.private_key_id = "dummy-private-key-id"
    Rails.application.credentials.dependencies.gcp.private_key = "-----BEGIN PRIVATE KEY-----\nDUMMYKEY\n-----END PRIVATE KEY-----"
    Rails.application.credentials.dependencies.gcp.client_email = "dummy@demo-app.iam.gserviceaccount.com"
    Rails.application.credentials.dependencies.gcp.client_id = "1234567890"
    Rails.application.credentials.dependencies.gcp.client_x509_cert_url = "https://www.googleapis.com/robot/v1/metadata/x509/dummy%40demo-app.iam.gserviceaccount.com"

    ENV["ARTIFACT_BUILDS_BUCKET_NAME"] = "dummy-bucket"
  end
end

module Site
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    add_dummy_gcp_config_for_demo_seed_mode

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks structured_logger.rb])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    config.eager_load_paths << Rails.root.join("lib")
    config.active_job.queue_adapter = :sidekiq
    config.active_model.i18n_customize_full_message = true
    config.assets.css_compressor = nil
    config.middleware.insert_after ActionDispatch::Static, Rack::Deflater
    config.action_dispatch.default_headers["X-XSS-Protection"] = "1; mode=block"
    PaperTrail.config.version_limit = 10
    config.active_storage.draw_routes = false
    config.lograge.enabled = false

    if ENV["RAILS_PIPELINE_ENV"].present?
      Rails.application.config.credentials.content_path =
        Rails.root.join("config/credentials/#{ENV["RAILS_PIPELINE_ENV"]}.yml.enc")
    end

    config.x.app_redirect = ENV["APP_REDIRECT_MAPPING_JSON"] ? JSON.parse(ENV["APP_REDIRECT_MAPPING_JSON"]) : {}

    config.before_configuration do
      require "redis_configuration"
      ::REDIS_CONFIGURATION = RedisConfiguration.new
    end
  end
end

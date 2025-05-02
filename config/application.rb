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
    config.autoload_lib(ignore: %w[assets tasks structured_logger.rb])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    config.eager_load_paths << Rails.root.join("lib")
    config.active_job.queue_adapter = :sidekiq
    config.active_model.i18n_customize_full_message = true
    config.assets.css_compressor = nil
    config.middleware.use Rack::Deflater
    config.action_dispatch.default_headers["X-XSS-Protection"] = "1; mode=block"
    PaperTrail.config.version_limit = 10
    config.active_storage.draw_routes = false
    config.lograge.enabled = false

    # Debug the master key issue
    begin
      key_content = ENV["RAILS_MASTER_KEY"]
      puts "DEBUG [application.rb]: Master key length: #{key_content ? key_content.length : 'nil'}"
      puts "DEBUG [application.rb]: RAILS_PIPELINE_ENV: #{ENV["RAILS_PIPELINE_ENV"].inspect}"

      creds_path = if ENV["RAILS_PIPELINE_ENV"].present?
        path = Rails.root.join("config/credentials/#{ENV["RAILS_PIPELINE_ENV"]}.yml.enc").to_s
        puts "DEBUG [application.rb]: Looking for credentials at: #{path}"
        puts "DEBUG [application.rb]: File exists: #{File.exist?(path)}"
        path
      else
        default_path = Rails.root.join("config/credentials.yml.enc").to_s
        puts "DEBUG [application.rb]: Using default credentials path: #{default_path}"
        puts "DEBUG [application.rb]: File exists: #{File.exist?(default_path)}"
        default_path
      end
    rescue => e
      puts "DEBUG [application.rb]: Error in key debugging: #{e.class} - #{e.message}"
    end

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

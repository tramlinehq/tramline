module Firebasable
  extend ActiveSupport::Concern

  CACHE_EXPIRY = 1.month

  APPS_TRANSFORMATIONS = {
    app_id: :app_id,
    display_name: :display_name,
    platform: :platform
  }

  included do
    encrypts :json_key, deterministic: true

    delegate :cache, to: Rails
    validate :correct_key, on: :create

    delegate :integrable, to: :integration
    delegate :config, to: :integrable
  end

  def access_key
    StringIO.new(json_key)
  end

  def creatable?
    true
  end

  def connectable?
    false
  end

  def store?
    false
  end

  def further_setup?
    true
  end

  def connection_data
    "Project: #{project_number}"
  end

  def setup
    android = list_apps(platform: "android")
    ios = list_apps(platform: "ios")

    case integrable.platform
    when "android" then {android: android}
    when "ios" then {ios: ios}
    when "cross_platform" then {ios: ios, android: android}
    else
      raise ArgumentError, "Invalid platform"
    end
  end

  def list_apps(platform:)
    apps = cache.fetch(list_apps_cache_key, expires_in: CACHE_EXPIRY) do
      firebase_installation.list_apps(self.class::APPS_TRANSFORMATIONS)
    end

    apps.select { |app| app[:platform] == platform }.map { |app| app.slice(:app_id, :display_name) }
  end

  def metadata
    {}
  end

  private

  def correct_key
    raise NotImplementedError, "Each model must define its own `correct_key` method"
  end
end

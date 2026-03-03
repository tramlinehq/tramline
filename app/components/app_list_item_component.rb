# frozen_string_literal: true

class AppListItemComponent < BaseComponent
  def initialize(app: {})
    @app = app || {}
  end

  attr_reader :app

  def name
    app["name"]
  end

  def description
    app["description"].truncate(100)
  end

  def icon_url
    app["iconUrl"]
  end

  def bundle_id
    app["bundleId"]
  end

  def store
    app["store"]
  end

  def store_label
    (store == "app-store") ? "App Store" : "Play Store"
  end

  def store_logo
    (store == "app-store") ? "integrations/logo_app_store.png" : "integrations/logo_google_play_store.png"
  end

  def rating
    app["averageRating"]
  end

  def app_url
    app["appUrl"]
  end

  def platform
    (store == "app-store") ? "ios" : "android"
  end

  def app_id
    "app_#{bundle_id&.parameterize}"
  end
end

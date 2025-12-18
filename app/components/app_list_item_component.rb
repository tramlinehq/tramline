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
    app["description"].truncate(50)
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

  def rating
    app["averageRating"]
  end

  def app_url
    app["appUrl"]
  end

  def platform
    store == "app-store" ? "ios" : "android"
  end
end

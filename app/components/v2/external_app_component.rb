class V2::ExternalAppComponent < V2::BaseComponent
  include ApplicationHelper
  include ButtonHelper
  include AssetsHelper

  LOGOS = {
    android: "integrations/logo_google_play_store.png",
    ios: "integrations/logo_app_store.png"
  }.freeze

  def initialize(app:)
    @app = app
    @latest_external_apps = @app.latest_external_apps
  end

  attr_reader :app, :latest_external_apps

  private

  def subtitle
    return "Last changed #{ago_in_words @latest_external_apps.values.first.fetched_at}." if external_apps?
    return "Fetching..." if app.has_store_integration?
    "Add store deployment integration to fetch this information."
  end

  def external_apps?
    @latest_external_apps.values.first.present?
  end

  def store_icon_path(platform)
    LOGOS[platform.to_sym]
  end

  def channels(external_app)
    external_app.channel_data.map(&:with_indifferent_access)
  end

  def channel_name(channel)
    channel[:name].humanize
  end

  def releases(channel)
    channel[:releases]&.sort_by { |r| r[:status] }
  end

  def release_status(release)
    status_badge(release[:status].titleize.humanize, %w[mx-1], :routine)
  end

  def release_version(release)
    release[:version_string]
  end

  def release_number(release)
    release[:build_number]
  end

  def release_percent(release)
    release[:user_fraction] * 100
  end
end

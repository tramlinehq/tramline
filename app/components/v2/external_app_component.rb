class V2::ExternalAppComponent < V2::BaseComponent
  include ApplicationHelper

  LOGOS = {
    android: "integrations/logo_google_play_store.png",
    ios: "integrations/logo_app_store.png"
  }.freeze

  def initialize(app:)
    @app = app
    @latest_external_apps =
      if @app.cross_platform?
        @app.latest_external_apps
      else
        @app.latest_external_apps.slice(@app.platform.to_sym)
      end
  end

  attr_reader :app, :latest_external_apps

  private

  def fetched_at
    ago_in_words @latest_external_apps.values.first.fetched_at
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

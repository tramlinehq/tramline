class ExternalAppComponent < ViewComponent::Base
  include ApplicationHelper
  include ButtonHelper
  include AssetsHelper

  def initialize(app:, external_app:)
    @app = app
    @external_app = external_app
  end

  attr_reader :external_app, :app

  private

  def column_names
    ["Channel Name", "Current Releases"]
  end

  def subtitle
    return "Last changed #{ago_in_words external_app.fetched_at}" if external_app
    return "Fetching..." if app.has_store_integration?
    "Add store deployment integration to fetch this information"
  end

  def channels
    external_app.channel_data.map(&:with_indifferent_access)
  end

  def channel_name(channel)
    channel[:name].humanize
  end

  def releases(channel)
    channel[:releases].sort_by { |r| r[:status] }
  end

  def release_status(release)
    status_badge(release[:status].titleize.humanize, %w[mx-1], :routine)
  end

  def release_description(release)
    "#{release[:version_string]} • #{release[:build_number]}"
  end

  def release_fraction_title(release)
    "Released to #{release_percent release}%"
  end

  def release_fraction_width(release)
    "#{release_percent release}%"
  end

  def release_percent(release)
    release[:user_fraction] * 100
  end
end

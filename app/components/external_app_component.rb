class ExternalAppComponent < ViewComponent::Base
  include ApplicationHelper

  def initialize(external_app:)
    @external_app = external_app
  end

  attr_reader :external_app

  private

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
    status_badge(release[:status].titleize.humanize, %w[bg-sky-100 text-sky-600 mx-1])
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

class ExternalAppComponent < ViewComponent::Base
  include ApplicationHelper

  def initialize(external_app:)
    @external_app = external_app
  end

  attr_reader :external_app

  def channels
    external_app.channel_data.map { |ch| ch.with_indifferent_access }
  end

  def releases(channel)
    channel[:releases].sort_by { |r| r[:status] }
  end

  def release_status(release)
    release[:status].titleize.humanize
  end

  def release_percent(release)
    release[:user_fraction] * 100
  end
end

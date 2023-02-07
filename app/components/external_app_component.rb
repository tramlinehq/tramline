class ExternalAppComponent < ViewComponent::Base
  include ApplicationHelper

  def initialize(external_app:)
    @external_app = external_app
  end

  attr_reader :external_app

  def channels
    external_app.channel_data.map { |ch| ch.with_indifferent_access }
  end
end

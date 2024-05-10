class RefreshExternalAppJob < ApplicationJob
  include Loggable
  queue_as :high
  sidekiq_options retry: 0, dead: false # skip DLQ

  def perform(app_id)
    app = App.find(app_id)
    return unless app
    app.create_external!
  end
end

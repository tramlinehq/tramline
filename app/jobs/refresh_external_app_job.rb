class RefreshExternalAppJob < ApplicationJob
  include Loggable
  queue_as :high

  def perform(app_id)
    app = App.find(app_id)
    return unless app

    app.create_external
  end
end

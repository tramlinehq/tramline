class RefreshExternalAppsJob < ApplicationJob
  include Loggable
  queue_as :high

  def perform
    App.all.each { |app| app.refresh_external_app }
  end
end

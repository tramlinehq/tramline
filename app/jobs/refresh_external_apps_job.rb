class RefreshExternalAppsJob < ApplicationJob
  include Loggable
  queue_as :high

  def perform
    apps = App.all
    return if apps.empty?

    apps.each do |app|
      RefreshExternalAppJob.perform_later(app.id)
    end
  end
end

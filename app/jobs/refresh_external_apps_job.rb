class RefreshExternalAppsJob < ApplicationJob
  include Loggable
  queue_as :high

  def perform
    return if Rails.env.development? && !ENV["REFRESH_EXTERNAL_APPS"]
    App.all.each do |app|
      next unless app.has_recent_activity?
      app.refresh_external_app if app.ready?
    end
  end
end

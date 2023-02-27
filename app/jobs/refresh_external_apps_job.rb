class RefreshExternalAppsJob < ApplicationJob
  include Loggable
  queue_as :high

  def perform
    return if Rails.env.development? && !ENV["REFRESH_EXTERNAL_APPS"]
    App.all.each { |app| app.refresh_external_app if app.ready? }
  end
end

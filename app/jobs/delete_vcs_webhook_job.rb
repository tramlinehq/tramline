class DeleteVcsWebhookJob < ApplicationJob
  sidekiq_options retry: 3

  # The train is already gone by the time this runs, so the webhook id is passed along explicitly
  def perform(app_id, vcs_webhook_id)
    app = App.find_by(id: app_id)
    return unless app

    app.vcs_provider&.delete_webhook!(vcs_webhook_id)
  end
end

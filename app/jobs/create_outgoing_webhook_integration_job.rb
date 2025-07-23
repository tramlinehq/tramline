class CreateOutgoingWebhookIntegrationJob < ApplicationJob
  def perform(train_id)
    train = Train.find(train_id)
    return unless train
    return if train.webhook_integration&.available?

    webhook_integration = train.create_webhook_integration!
    webhook_integration.create_app!
  end
end

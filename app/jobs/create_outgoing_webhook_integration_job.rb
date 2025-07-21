class CreateOutgoingWebhookIntegrationJob < ApplicationJob
  def perform(train_id)
    train = Train.find(train_id)
    return unless train

    # Create SvixIntegration directly associated with train
    webhook_integration = train.webhook_integration || train.create_webhook_integration!

    webhook_integration.create_svix_app!
  end
end

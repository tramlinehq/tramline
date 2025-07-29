class UpdateOutgoingWebhookIntegrationJob < ApplicationJob
  def perform(train_id, enabled = true)
    train = Train.find(train_id)
    return unless train

    if enabled
      create_webhook_integration(train)
    else
      delete_webhook_integration(train)
    end
  end

  private

  def create_webhook_integration(train)
    return if train.webhook_integration&.available?

    webhook_integration = train.create_webhook_integration!
    webhook_integration.create_app!
  end

  def delete_webhook_integration(train)
    return unless train.webhook_integration&.available?

    train.webhook_integration.delete_app!
    train.webhook_integration.destroy!
  end
end

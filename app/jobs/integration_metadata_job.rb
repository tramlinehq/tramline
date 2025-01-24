class IntegrationMetadataJob < ApplicationJob
  def perform(integration_id)
    integration = Integration.find(integration_id)
    return unless integration

    integration.set_metadata!
  end
end

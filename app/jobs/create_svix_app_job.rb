class CreateSvixAppJob < ApplicationJob
  def perform(train_id)
    train = Train.find(train_id)
    return unless train

    svix_integration = train.integrations.webhook.first&.providable

    if svix_integration.nil?
      integration = train.integrations.create!(
        category: :webhook,
        providable: SvixIntegration.new,
        status: :connected
      )
      svix_integration = integration.providable
    end

    svix_integration.create_svix_app!
  end
end

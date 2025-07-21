class CreateSvixAppJob < ApplicationJob
  def perform(train_id)
    train = Train.find(train_id)
    return unless train

    # Create SvixIntegration directly associated with train
    svix_integration = train.svix_integration || train.create_svix_integration!

    svix_integration.create_svix_app!
  end
end

class Webhooks::ProcessPushWebhookJob < ApplicationJob
  queue_as :high

  def perform(train_id, push_params)
    train = Train.find(train_id)
    Webhooks::Push.process(train, push_params.with_indifferent_access)
  end
end

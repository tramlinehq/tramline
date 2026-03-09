class Webhooks::ProcessPullRequestWebhookJob < ApplicationJob
  queue_as :high

  def perform(train_id, pull_request_params)
    train = Train.find_by(id: train_id)
    return unless train
    Webhooks::PullRequest.process(train, pull_request_params.with_indifferent_access)
  end
end

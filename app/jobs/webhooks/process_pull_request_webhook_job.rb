class Webhooks::ProcessPullRequestWebhookJob < ApplicationJob
  queue_as :high

  def perform(train_id, pull_request_params)
    train = Train.find(train_id)
    Webhooks::PullRequest.process(train, pull_request_params.with_indifferent_access)
  end
end

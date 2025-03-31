class RefreshWorkflowsJob < ApplicationJob
  sidekiq_options retry: 0, dead: false # skip DLQ

  def perform(train_id)
    train = Train.find(train_id)
    return unless train

    train.workflows(bust_cache: true)
  end
end

class WebhookProcessors::PushJob < ApplicationJob
  queue_as :high

  def perform(train_run_id, head_commit_attributes, rest_commit_attributes)
    run = Release.find(train_run_id)
    return unless run.committable?

    WebhookProcessors::Push.process(run, commit_attributes, rest_commit_attributes)
  end
end

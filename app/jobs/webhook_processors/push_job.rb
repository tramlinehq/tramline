class WebhookProcessors::PushJob < ApplicationJob
  queue_as :high

  def perform(train_run_id, head_commit, rest_commits)
    run = Release.find(train_run_id)
    return unless run.committable?
    WebhookProcessors::Push.process(run, head_commit, rest_commits)
  end
end

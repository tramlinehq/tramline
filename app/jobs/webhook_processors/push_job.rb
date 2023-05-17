class WebhookProcessors::PushJob < ApplicationJob
  queue_as :high

  def perform(train_run_id, commit_attributes)
    run = Releases::Train::Run.find(train_run_id)
    return unless run.committable?

    WebhookProcessors::Push.process(run, commit_attributes)
  end
end

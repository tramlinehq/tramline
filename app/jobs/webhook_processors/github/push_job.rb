class WebhookProcessors::Github::PushJob < ApplicationJob
  queue_as :high

  def perform(train_run_id, commit_attributes)
    release = Releases::Train::Run.find(train_run_id)
    release.with_lock do
      return unless release.committable?
      WebhookProcessors::Github::Push.process(release, commit_attributes)
    end
  end
end

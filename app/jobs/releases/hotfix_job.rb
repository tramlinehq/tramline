class Releases::HotfixJob < ApplicationJob
  queue_as :high

  def perform(release_id)
    run = Release.find(release_id)
    # simulate a webhook push for a new branch / new commit
    # with the latest head commit of the release branch
    WebhookProcessors::Push.process(run, run.latest_commit_hash(sha_only: false), [])
  end
end

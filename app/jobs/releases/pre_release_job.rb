class Releases::PreReleaseJob < ApplicationJob
  queue_as :high

  def perform(release_id)
    run = Release.find(release_id)

    if run.retrigger_for_hotfix?
      return WebhookProcessors::Push.process(run, run.latest_commit_hash(sha_only: false), [])
    end

    Triggers::PreRelease.call(run)
  end
end

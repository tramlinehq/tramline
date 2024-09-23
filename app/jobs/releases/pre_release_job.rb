class Releases::PreReleaseJob < ApplicationJob
  queue_as :high

  def perform(release_id)
    release = Release.find(release_id)

    if release.retrigger_for_hotfix?
      latest_commit = release.latest_commit_hash(sha_only: false)
      return WebhookProcessors::Push.process(release, latest_commit, []) unless release.is_v2?
      return Signal.commits_have_landed!(release, latest_commit, []) if release.is_v2?
    end

    Triggers::PreRelease.call(release)
  end
end

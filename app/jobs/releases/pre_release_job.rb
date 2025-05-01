class Releases::PreReleaseJob < ApplicationJob
  queue_as :high

  def perform(release_id)
    release = Release.find(release_id)

    if release.hotfix_with_existing_branch?
      latest_commit = release.latest_commit_hash(sha_only: false)
      return Signal.commits_have_landed!(release, latest_commit, [])
    end

    Triggers::PreRelease.call(release)
  end
end

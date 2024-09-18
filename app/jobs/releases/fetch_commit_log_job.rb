class Releases::FetchCommitLogJob < ApplicationJob
  queue_as :high

  def perform(release_id)
    release = Release.find(release_id)
    release.fetch_commit_log
  end
end

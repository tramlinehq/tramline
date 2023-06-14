class Releases::FetchCommitLogJob < ApplicationJob
  queue_as :high

  def perform(release_id)
    run = Release.find(release_id)
    run.fetch_commit_log
  end
end

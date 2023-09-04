class Releases::BackmergeCommitJob < ApplicationJob
  include Loggable

  queue_as :high

  def perform(commit_id)
    commit = Commit.find_by(id: commit_id)
    return unless commit.release.committable?
    Triggers::ReleaseBackmerge.call(commit)
  end
end

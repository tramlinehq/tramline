class Releases::BackmergeCommitJob < ApplicationJob
  include Loggable

  queue_as :high

  def perform(commit_id, is_head_commit: false)
    commit = Commit.find(commit_id)
    Triggers::ReleaseBackmerge.call(commit, is_head_commit:)
  end
end

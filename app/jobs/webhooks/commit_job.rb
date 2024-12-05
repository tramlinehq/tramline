class Webhooks::CommitJob < ApplicationJob
  queue_as :high

  def perform(train_run_id, head_commit, rest_commits)
    release = Release.find(train_run_id)
    return unless release.committable?
    Signal.commit_has_landed!(release, head_commit)
  end
end

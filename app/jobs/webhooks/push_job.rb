class Webhooks::PushJob < ApplicationJob
  queue_as :high

  def perform(train_run_id, head_commit, rest_commits)
    release = Release.find(train_run_id)
    return unless release.committable?
    Signal.commits_have_landed!(release, head_commit.with_indifferent_access, rest_commits.map(&:with_indifferent_access))
  end
end

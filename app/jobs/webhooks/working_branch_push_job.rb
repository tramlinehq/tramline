class Webhooks::WorkingBranchPushJob < ApplicationJob
  queue_as :high

  def perform(release_id, head_commit, rest_commits)
    release = Release.find(release_id)
    return unless release.committable?

    all_commits = [head_commit.with_indifferent_access] + rest_commits.map(&:with_indifferent_access)
    all_commits.each do |commit_data|
      create_forward_merge_entry!(release, commit_data)
    end
  end

  private

  def create_forward_merge_entry!(release, commit_data)
    release.with_lock do
      return if release.forward_merge_queue
        .joins(:commit)
        .exists?(commits: {commit_hash: commit_data[:commit_hash]})

      fmq = ForwardMergeQueue.create!(release:)
      Commit.create!(
        commit_data
          .slice(:commit_hash, :message, :author_name, :author_email, :author_login, :url, :timestamp)
          .merge(release:, forward_merge_queue: fmq)
      )
    end
  end
end

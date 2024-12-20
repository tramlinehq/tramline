class Commit::ContinuousBackmergeJob < ApplicationJob
  MAX_RETRIES = 5
  include Loggable
  include Backoffable
  queue_as :high

  def perform(commit_id, is_head_commit: false, count: 0)
    @commit = Commit.find(commit_id)
    @is_head_commit = is_head_commit
    @count = count

    return if skip_backmerge?

    result = release.with_lock do
      return unless backmerge_allowed?
      Triggers::PatchPullRequest.create!(release, commit)
    end

    handle_failure(result) if result && !result.ok?
  end

  private

  def handle_failure(result)
    err = result.error
    if err.is_a?(Installations::Error) && err.reason == :pull_request_failed_merge_check
      if @count < MAX_RETRIES
        attempt = @count + 1
        Commit::ContinuousBackmergeJob
          .set(wait: backoff_in(attempt:, period: :minutes, type: :static, factor: 1))
          .perform_later(commit.id, is_head_commit: @is_head_commit, count: attempt)
      end

      return
    end

    elog(err)
    commit.update!(backmerge_failure: true)
    release.event_stamp!(reason: :backmerge_failure, kind: :error, data: stamp_data)
    commit.notify!("Backmerge to the working branch failed", :backmerge_failed, commit.notification_params)
  end

  def stamp_data
    {commit_url: commit.url, commit_sha: commit.short_sha}
  end

  def skip_backmerge?
    release.organization.single_pr_backmerge_for_multi_commit_push? && !@is_head_commit
  end

  def backmerge_allowed?
    train.almost_trunk? && train.continuous_backmerge? && release.committable? && release.stability_commit?(commit)
  end

  attr_reader :commit
  delegate :train, to: :release
  delegate :release, to: :commit
end

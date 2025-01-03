class Commit::ContinuousBackmergeJob < ApplicationJob
  MAX_RETRIES = 32
  include Loggable
  include Backoffable
  queue_as :high

  def perform(commit_id, is_head_commit: false, count: 0)
    @commit = Commit.find(commit_id)

    return if skip_backmerge?(is_head_commit)

    result = release.with_lock do
      return unless backmerge_allowed?
      Triggers::PatchPullRequest.call(release, commit)
    end

    return unless result
    commit.reload # ensure the commit is updated with the latest data, and no stale state is associated with it
    return handle_success(commit.pull_request) if result.ok?
    return handle_retry(count, is_head_commit) if retryable?(result)
    handle_failure(result.error)
  end

  private

  def handle_failure(err)
    elog(err)
    commit.update!(backmerge_failure: true)
    release.event_stamp!(reason: :backmerge_failure, kind: :error, data: stamp_data)
    commit.notify!("Backmerge to the working branch failed", :backmerge_failed, commit.notification_params)
  end

  def handle_retry(count, is_head_commit)
    if count < MAX_RETRIES
      attempt = count + 1
      Commit::ContinuousBackmergeJob
        .set(wait: backoff_in(attempt:, period: :minutes, type: :linear, factor: 5))
        .perform_later(commit.id, is_head_commit:, count: attempt)
    end
  end

  def skip_backmerge?(is_head_commit)
    release.organization.single_pr_backmerge_for_multi_commit_push? && !is_head_commit
  end

  def backmerge_allowed?
    train.almost_trunk? && train.continuous_backmerge? && release.committable? && release.stability_commit?(commit)
  end

  def retryable?(result)
    !result.ok? && result.error.is_a?(Triggers::PullRequest::RetryableMergeError)
  end

  def handle_success(pr)
    return unless pr
    logger.debug { "Patch Pull Request: Created a patch PR successfully: #{pr}" }
    release.event_stamp!(reason: :backmerge_pr_created, kind: :success, data: stamp_data(pr))
  end

  def stamp_data(pr = nil)
    {url: pr&.url, number: pr&.number, commit_url: commit.url, commit_sha: commit.short_sha}
  end

  attr_reader :commit
  delegate :train, to: :release
  delegate :release, to: :commit
end

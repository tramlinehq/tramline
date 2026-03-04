class Commit::CherryPickJob < ApplicationJob
  MAX_RETRIES = 32
  queue_as :high

  def perform(forward_merge_queue_id, count = 0)
    @forward_merge_queue = ForwardMergeQueue.find(forward_merge_queue_id)

    return unless release.committable?
    return unless forward_merge_queue.actionable?

    forward_merge_queue.update!(status: "in_progress")

    result = release.with_lock do
      Triggers::CherryPickPullRequest.call(release, forward_merge_queue)
    end

    return unless result
    return handle_success if result.ok?
    return handle_retry(count) if retryable?(result)
    handle_failure(result.error)
  end

  private

  attr_reader :forward_merge_queue

  delegate :release, to: :forward_merge_queue
  delegate :train, to: :release
  delegate :commit, to: :forward_merge_queue

  def handle_success
    forward_merge_queue.update!(status: "success")
    release.event_stamp!(reason: :cherry_pick_succeeded, kind: :success, data: stamp_data)
  end

  def handle_failure(err)
    elog(err, level: :debug)
    forward_merge_queue.update!(status: "failed")
    release.event_stamp!(reason: :cherry_pick_failed, kind: :error, data: stamp_data)
    commit.notify!("Cherry-pick to the release branch failed", :backmerge_failed, commit.notification_params)
  end

  def handle_retry(count)
    if count < MAX_RETRIES
      attempt = count + 1
      Commit::CherryPickJob
        .set(wait: backoff_in(attempt:, period: :minutes, type: :linear, factor: 5))
        .perform_async(forward_merge_queue.id, attempt)
    else
      handle_failure(StandardError.new("Max retries exhausted for cherry-pick"))
    end
  end

  def retryable?(result)
    !result.ok? && result.error.is_a?(Triggers::PullRequest::RetryableMergeError)
  end

  def stamp_data
    {commit_url: commit.url, commit_sha: commit.short_sha}
  end
end

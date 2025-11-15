class Coordinators::PreReleaseJob < ApplicationJob
  RELEASE_HANDLERS = {
    "almost_trunk" => Coordinators::PreRelease::AlmostTrunk,
    "parallel_working" => Coordinators::PreRelease::ParallelBranches,
    "release_backmerge" => Coordinators::PreRelease::ReleaseBackMerge
  }

  queue_as :high
  sidekiq_options retry: 2

  sidekiq_retry_in do |count, ex, msg|
    if retryable_failure?(ex)
      backoff_in(attempt: count + 1, period: :minutes, type: :static, factor: 1).to_i
    elsif trigger_failure?(ex)
      mark_failed!(msg, ex)
      :kill
    else
      :kill
    end
  end

  sidekiq_retries_exhausted do |msg, ex|
    if retryable_failure?(ex)
      mark_failed!(msg, ex)
    end
  end

  def perform(release_id)
    release = Release.find(release_id)
    release_branch = release.release_branch
    train = release.train
    branching_strategy = train.branching_strategy

    if release.hotfix_with_existing_branch?
      latest_commit = release.latest_commit_hash(sha_only: false)
      return Signal.commits_have_landed!(release, latest_commit, [])
    end

    release.start_pre_release_phase!
    RELEASE_HANDLERS[branching_strategy].call(release, release_branch).value!
  end

  def self.mark_failed!(msg, ex)
    release = Release.find(msg["args"].first)
    elog(ex, level: :warn)
    release.fail_pre_release_phase!
    release.event_stamp!(reason: :pre_release_failed, kind: :error, data: {error: ex.message})
  end

  def self.trigger_failure?(ex)
    ex.is_a?(Triggers::Errors)
  end

  def self.retryable_failure?(ex)
    ex.is_a?(Triggers::Branch::RetryableBranchCreateError)
  end
end

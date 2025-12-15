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
    elsif existing_branch?(ex)
      signal_commits_have_landed!(msg)
      :kill
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
      return signal_commits_have_landed!(release)
    end

    release.start_pre_release_phase!
    result = RELEASE_HANDLERS[branching_strategy].call(release, release_branch)

    if !result.ok? && result.error.is_a?(Triggers::Branch::BranchAlreadyExistsError)
      return signal_commits_have_landed!(release)
    end

    result.value!
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

  def self.existing_branch?(ex)
    ex.is_a?(Triggers::Branch::BranchAlreadyExistsError)
  end

  def self.signal_commits_have_landed!(msg)
    release = Release.find(msg["args"].first)
    new.signal_commits_have_landed!(release)
  end

  private

  def signal_commits_have_landed!(release)
    latest_commit = release.latest_commit_hash(sha_only: false)
    Signals.commits_have_landed!(release, latest_commit, [])
  end
end

class Triggers::PreRelease
  include Memery

  RELEASE_HANDLERS = {
    "almost_trunk" => AlmostTrunk,
    "parallel_working" => ParallelBranches,
    "release_backmerge" => ReleaseBackMerge
  }

  def self.call(release)
    new(release).call
  end

  def initialize(release)
    @release = release
  end

  delegate :train, :release_branch, to: :release
  delegate :branching_strategy, to: :train
  attr_reader :release

  def call
    RELEASE_HANDLERS[branching_strategy].call(release, release_branch).value!
  rescue Triggers::PullRequest::CreateError
    release.event_stamp!(reason: :pre_release_pr_not_creatable, kind: :error, data: {release_branch:})
    release.stop!
  rescue Triggers::PullRequest::MergeError
    Rails.logger.debug { "Pre-release pull request not merged: #{release.pull_requests.pre_release}" }
  end
end

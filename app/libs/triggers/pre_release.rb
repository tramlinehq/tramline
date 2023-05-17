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
    # fail the release, audit it
  rescue Triggers::PullRequest::MergeError
    # audit it
    # move it to a pre_release state
    # handle pre_release -> on_track transition to close the PR
  end
end

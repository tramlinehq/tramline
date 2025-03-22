class Triggers::PreRelease
  include Memery
  include Loggable

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
    release.start_pre_release_phase!
    RELEASE_HANDLERS[branching_strategy].call(release, release_branch).value!
  rescue Triggers::Errors => ex
    elog(ex, level: :warn)
    release.fail_pre_release_phase!
    release.event_stamp!(reason: :pre_release_failed, kind: :error, data: {error: ex.message})
  end
end

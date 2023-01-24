class Triggers::PostRelease
  def self.call(release)
    new(release).call
  end

  def initialize(release)
    @release = release
  end

  POST_RELEASE_HANDLERS = {
    "almost_trunk" => AlmostTrunk,
    "parallel_working" => ParallelBranches,
    "release_backmerge" => ReleaseBackMerge
  }

  def call
    result = POST_RELEASE_HANDLERS[train.branching_strategy].call(release)
    release.reload

    if result.ok?
      release.finish!
    else
      release.fail_post_release_phase!
      release.event_stamp!(reason: :finalize_failed, kind: :error, data: {version: release.release_version})
      Sentry.capture_exception(result.error)
    end
  end

  private

  attr_reader :release
  delegate :train, to: :release
end

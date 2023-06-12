class Triggers::PostReleaseGroup
  include Loggable

  def self.call(release)
    new(release).call
  end

  def initialize(release)
    @release = release
  end

  POST_RELEASE_HANDLERS = {
    "almost_trunk" => Triggers::PostRelease::AlmostTrunk,
    "parallel_working" => Triggers::PostRelease::ParallelBranches,
    "release_backmerge" => Triggers::PostRelease::ReleaseBackMerge
  }

  def call
    release.with_lock do
      return unless release.post_release_started?

      release.event_stamp!(reason: :finalizing, kind: :notice, data: {version: release.release_version})
      result = POST_RELEASE_HANDLERS[train.branching_strategy].call(release)
      release.reload

      if result.ok?
        release.finish!
      else
        release.fail_post_release_phase!
        release.event_stamp!(reason: :finalize_failed, kind: :error, data: {version: release.release_version})
        elog(result.error)
      end
    end
  end

  private

  attr_reader :release
  delegate :train, to: :release
end

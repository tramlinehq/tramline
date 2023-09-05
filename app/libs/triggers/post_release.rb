class Triggers::PostRelease
  include Loggable

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
    release.with_lock do
      return unless release.post_release_started?

      if release.pull_requests.open.exists?
        release.fail_post_release_phase!
      else
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
  end

  private

  attr_reader :release
  delegate :train, to: :release
end

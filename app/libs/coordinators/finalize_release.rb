class Coordinators::FinalizeRelease
  include Loggable

  def self.call(release, force_finalize = false)
    new(release, force_finalize).call
  end

  def initialize(release, force_finalize = false)
    @release = release
    @force_finalize = force_finalize
  end

  POST_RELEASE_HANDLERS = {
    "almost_trunk" => AlmostTrunk,
    "parallel_working" => ParallelBranches,
    "release_backmerge" => ReleaseBackMerge
  }

  def call
    release.with_lock do
      return unless release.post_release_started?

      if release.pull_requests.automatic.open.exists? || (release.unmerged_commits.exists? && !force_finalize)
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

  delegate :train, to: :release
  attr_reader :release, :force_finalize
end

class Coordinators::FinalizeRelease
  include Loggable

  def self.call(release, force_finalize = false)
    new(release, force_finalize).call
  end

  def initialize(release, force_finalize = false)
    @release = release
    @force_finalize = force_finalize
  end

  HANDLERS = {
    "almost_trunk" => AlmostTrunk,
    "parallel_working" => ParallelBranches,
    "release_backmerge" => ReleaseBackMerge
  }

  def call
    release.with_lock do
      return unless release.post_release_started?
      open_pull_requests = release.pull_requests.automatic.open

      if open_pull_requests.exists? || (release.unmerged_commits.exists? && !force_finalize)
        release.fail_post_release_phase!
        on_failure!
      else
        release.event_stamp!(reason: :finalizing, kind: :notice, data: {version: release_version})
        result = HANDLERS[train.branching_strategy].call(release)
        release.reload

        if result.ok?
          release.finish!
          on_finish!
        else
          release.fail_post_release_phase!
          elog(result.error)
          on_failure!
        end
      end
    end
  end

  private

  def on_finish!
    release.update_train_version!
    release.event_stamp!(reason: :finished, kind: :success, data: {version: release_version})
    release.notify!("Release has finished!", :release_ended, release.notification_params)
    RefreshReportsJob.perform_later(release.id)
  end

  def on_failure!
    release.event_stamp!(reason: :finalize_failed, kind: :error, data: {version: release_version})
  end

  attr_reader :release, :force_finalize
  delegate :train, :release_version, to: :release
end

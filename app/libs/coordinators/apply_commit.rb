class Coordinators::ApplyCommit
  def self.call(release, commit)
    new(release, commit).call
  end

  def initialize(release, commit)
    @release = release
    @commit = commit
  end

  def call
    return unless commit.applicable?
    release.release_platform_runs.each do |run|
      # Apply commits to platform runs that can accept commits (created, on_track, or concluded without supersede)
      next unless run.committable?

      # If platform was concluded, transition back to on_track since there's new work
      reactivate_if_concluded(run)

      if release.hotfix?
        Coordinators::CreateBetaRelease.call(run, commit) if trigger_hotfix?
      else
        trigger(run)
      end
    end
  end

  private

  def trigger(run)
    return unless apply_change?(run)

    if run.conf.internal_release?
      Coordinators::CreateInternalRelease.call(run, commit)
    else
      Coordinators::CreateBetaRelease.call(run, commit)
    end
  end

  def trigger_hotfix?
    release.hotfixed_from.last_commit.commit_hash != commit.commit_hash
  end

  def apply_change?(run)
    return true if run.train.auto_apply_patch_changes?

    !run.version_bump_required?
  end

  def reactivate_if_concluded(run)
    return unless run.concluded?

    run.with_lock do
      run.start! if run.concluded?
    end

    run.event_stamp!(
      reason: :reactivated,
      kind: :notice,
      data: {version: run.release_version, commit: commit.short_sha}
    )
  end

  attr_reader :release, :commit
end

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
      next unless run.on_track?

      binding.pry
      if release.hotfix?
        Coordinators::CreateBetaRelease.call(run, commit) if trigger_hotfix?
      else
        if run.version_bump_required?
          binding.pry
          queue_commit_and_create_version_bump_pr(run, commit)
        else
          trigger(run)
        end
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

  def queue_commit_and_create_version_bump_pr(run, commit)
    release.active_build_queue.add_commit!(commit, can_apply: false)
    binding.pry
    unless run.has_pending_version_bump_pr?
      Coordinators::CreateVersionBumpPR.call(run)
    end
  end

  attr_reader :release, :commit
end

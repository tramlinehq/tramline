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

      if release.hotfix?
        Coordinators::CreateBetaRelease.call(run, commit) if trigger_hotfix?
      else
        trigger(run)
      end
    end
  end

  private

  def trigger(run)
    return unless change_auto_applicable?(run)

    if run.conf.internal_release?
      Coordinators::CreateInternalRelease.call(run, commit)
    else
      Coordinators::CreateBetaRelease.call(run, commit)
    end
  end

  def trigger_hotfix?
    release.hotfixed_from.last_commit.commit_hash != commit.commit_hash
  end

  def change_auto_applicable?(run)
    return true if run.train.auto_apply_patch_changes?

    !run.version_bump_required?
  end

  attr_reader :release, :commit
end

class Coordinators::ApplyCommit
  include Loggable
  RELEASE_STEPS = %w[InternalRelease BetaRelease]

  def self.call(release, commit, release_step: nil)
    new(release, commit, release_step:).call
  end

  def initialize(release, commit, release_step: nil)
    @release = release
    @commit = commit
    @release_step = release_step
  end

  def call
    return unless commit.applicable?
    release.release_platform_runs.each do |run|
      next unless run.on_track?

      run.bump_version!
      run.update!(last_commit: commit)

      if release.hotfix?
        pre_select_trigger(run) if trigger_hotfix?
      else
        trigger(run)
      end
    end
  end

  private

  def pre_select_trigger(run)
    case release_step
    when "InternalRelease"
      Coordinators::CreateInternalRelease.call(run, commit)
    when "BetaRelease"
      Coordinators::CreateBetaRelease.call(run, nil, commit)
    else
      Coordinators::CreateBetaRelease.call(run, nil, commit)
    end
  end

  def trigger(run)
    if run.conf.internal_release? && release_step.nil?
      Coordinators::CreateInternalRelease.call(run, commit)
    else
      Coordinators::CreateBetaRelease.call(run, nil, commit)
    end
  end

  def trigger_hotfix?
    release.hotfixed_from.last_commit.commit_hash != commit.commit_hash
  end

  delegate :train, to: :release
  attr_reader :release, :commit, :release_step
end

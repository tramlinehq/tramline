class Coordinators::ApplyCommit
  include Loggable
  RELEASE_STEPS = %w[InternalRelease BetaRelease]

  def self.call(release, commit, release_step: nil)
    new(release, commit, release_step:).call
  end

  def initialize(release, commit, release_step: nil)
    raise ArgumentError, "release_step must be one of #{RELEASE_STEPS}" unless RELEASE_STEPS.include?(release_step)
    @release = release
    @commit = commit
    @release_step = release_step
  end

  def call
    return unless commit.applicable?
    release.release_platform_runs.each do |run|
      trigger_release_for(run)
    end
  end

  private

  def trigger_release_for(run)
    return unless run.on_track?
    run.bump_version!
    run.update!(last_commit: commit)

    if release.hotfix?
      case release_step
      when "InternalRelease"
        Coordinators::CreateInternalRelease.call(run, commit)
      when "BetaRelease"
        Coordinators::CreateBetaRelease.call(run, nil, commit.id)
      else
        Coordinators::CreateInternalRelease.call(run, commit)
      end

      return
    end

    if run.conf.internal_release? && release_step.nil?
      Coordinators::CreateInternalRelease.call(run, commit)
    else
      Coordinators::CreateBetaRelease.call(run, nil, commit.id)
    end
  end

  attr_reader :release, :commit, :release_step
  delegate :train, to: :release
end

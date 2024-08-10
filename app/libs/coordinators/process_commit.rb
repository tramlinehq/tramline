class Coordinators::ProcessCommit
  include Loggable

  def self.call(release, commit)
    new(release, commit).call
  end

  def initialize(release, commit)
    @release = release
    @commit = commit
  end

  def call
    return commit.add_to_build_queue! if release.queue_commit?
    return unless commit.applicable?

    # TODO: [V2] change this to use the new have not started submission check
    release.release_platform_runs.have_not_submitted_production.each do |run|
      trigger_release_for(run)
    end
  end

  private

  def trigger_release_for(run)
    return if release.hotfix?

    train.fixed_build_number? ? run.bump_version_for_fixed_build_number! : run.bump_version!
    run.update!(last_commit: commit)

    if run.conf.internal_release?
      Coordinators::CreateInternalRelease.call(run, commit.id)
    else
      Coordinators::CreateBetaRelease.call(run, nil, commit.id)
    end
  end

  attr_reader :release, :commit
  delegate :train, to: :release
end

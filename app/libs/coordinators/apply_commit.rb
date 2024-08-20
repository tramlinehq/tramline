class Coordinators::ApplyCommit
  include Loggable

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
      trigger_release_for(run)
    end
  end

  private

  def trigger_release_for(run)
    return if release.hotfix?

    run.bump_version!
    run.update!(last_commit: commit)

    if run.conf.internal_release?
      Coordinators::CreateInternalRelease.call(run, commit)
    else
      Coordinators::CreateBetaRelease.call(run, nil, commit.id)
    end
  end

  attr_reader :release, :commit
  delegate :train, to: :release
end

class Coordinators::CreateInternalRelease
  def self.call(release_platform_run, commit)
    new(release_platform_run, commit).call
  end

  def initialize(release_platform_run, commit)
    @release_platform_run = release_platform_run
    @commit = commit
  end

  def call
    transaction do
      release_platform_run.correct_version!
      internal_release = release_platform_run.internal_releases.create!(config:, previous:, commit:)
      auto_promote = internal_release.conf.auto_promote?
      WorkflowRun.create_and_trigger!(workflow_config, internal_release, commit, release_platform_run, auto_promote:)
      internal_release.previous&.workflow_run&.cancel_workflow!
    end
  end

  private

  def previous
    release_platform_run.latest_internal_release
  end

  def config
    release_platform_run.conf.internal_release.as_json
  end

  def workflow_config
    release_platform_run.conf.pick_internal_workflow
  end

  attr_reader :release_platform_run, :commit
  delegate :transaction, to: BetaRelease
end

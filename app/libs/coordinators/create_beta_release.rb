class Coordinators::CreateBetaRelease
  def self.call(release_platform_run, commit)
    new(release_platform_run, commit).call
  end

  def initialize(release_platform_run, commit)
    raise ArgumentError, "Commit is required" if commit.blank?
    raise ArgumentError, "Beta release is blocked" unless release_platform_run.ready_for_beta_release?

    @release_platform_run = release_platform_run
    @commit = commit
  end

  def call
    return unless release_platform_run.on_track?

    transaction do
      release_platform_run.update_last_commit!(commit)
      release_platform_run.bump_version!
      release_platform_run.correct_version!
      beta_release = release_platform_run.beta_releases.create!(config:, previous:, commit:)
      WorkflowRun.create_and_trigger!(rc_workflow_config, beta_release, commit, release_platform_run)
      beta_release.previous&.workflow_run&.cancel_workflow!
    end
  end

  private

  def previous
    release_platform_run.latest_beta_release
  end

  def config
    release_platform_run.conf.beta_release.value
  end

  def workflows_config
    release_platform_run.conf.workflows
  end

  def rc_workflow_config
    workflows_config.release_candidate_workflow
  end

  attr_reader :release_platform_run, :build, :commit
  delegate :transaction, to: BetaRelease
end

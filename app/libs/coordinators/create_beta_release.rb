class Coordinators::CreateBetaRelease
  def self.call(release_platform_run, build, commit)
    new(release_platform_run, build, commit).call
  end

  def initialize(release_platform_run, build, commit)
    raise ArgumentError, "Only expects one of build or commit" if build.present? && commit.present?
    raise ArgumentError, "At least expects one of build or commit" if build.blank? && commit.blank?
    raise ArgumentError, "Beta release is blocked" unless release_platform_run.ready_for_beta_release?

    @release_platform_run = release_platform_run
    @build = build
    @commit = commit
  end

  def call
    return unless release_platform_run.on_track?

    transaction do
      beta_release = release_platform_run.beta_releases.new(config:, previous:)

      if build.present? && workflows_config.carryover_build?
        beta_release.commit = build.commit
        beta_release.parent_internal_release = build.workflow_run.triggering_release
        beta_release.save!
        beta_release.trigger_submissions!
      else
        beta_release.commit = commit
        beta_release.save!
        auto_promote = true
        release_platform_run.correct_version!
        WorkflowRun.create_and_trigger!(rc_workflow_config, beta_release, commit, release_platform_run, auto_promote:)
      end

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

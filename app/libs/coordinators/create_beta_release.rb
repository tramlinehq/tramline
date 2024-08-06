class Coordinators::CreateBetaRelease
  def self.call(release_platform_run, build_id, commit_id)
    new(release_platform_run, build_id, commit_id).call
  end

  def initialize(release_platform_run, build_id, commit_id)
    raise ArgumentError, "Only expects one of build or commit" if build_id.present? && commit_id.present?
    raise ArgumentError, "At least expects one of build or commit" if build_id.blank? && commit_id.blank?
    raise ArgumentError, "Beta release is blocked" unless release_platform_run.ready_for_beta_release?

    @release_platform_run = release_platform_run
    @build = release_platform_run.builds.find(build_id) if build_id.present?
    @commit = release_platform_run.release.all_commits.find(commit_id) if commit_id.present?
  end

  delegate :transaction, to: BetaRelease

  def call
    transaction do
      beta_release = @release_platform_run.beta_releases.new(config:, previous:)

      if carryover_build?
        beta_release.commit = @build.commit
        beta_release.parent_internal_release = @build.workflow_run.triggering_release
        beta_release.save!
        beta_release.trigger_submissions!
      else
        beta_release.commit = @commit
        beta_release.save!
        beta_release.trigger_workflow!(rc_workflow_config, auto_promote: true)
      end
    end
  end

  private

  def carryover_build?
    @build.present? && !workflows_config.separate_rc_workflow?
  end

  def previous
    @release_platform_run.latest_beta_release
  end

  def config
    @release_platform_run.conf.beta_release.value
  end

  def rc_workflow_config
    workflows_config.release_candidate_workflow
  end

  def workflows_config
    @release_platform_run.conf.workflows
  end
end

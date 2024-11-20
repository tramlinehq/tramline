class Coordinators::CreateBetaRelease
  def self.call(release_platform_run, commit)
    new(release_platform_run, commit).call

    if release_platform_run.release.release_platform_runs.all? { |run| run.beta_releases.exists?(commit: commit) } &&
        release_platform_run.train.trunk?

      tag_name = "v#{release_platform_run.release_version}"
      release_platform_run.train.create_tag!(tag_name, commit.commit_hash)

      release_platform_run.release.release_platform_runs.each do |run|
        run.update!(tag_name: tag_name)
        ReleasePlatformRuns::TriggerWorkflowJob.perform_later(run.id, commit.id)
      end
    end
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

      unless release_platform_run.train.trunk?
        WorkflowRun.create_and_trigger!(rc_workflow_config, beta_release, commit, release_platform_run)
      end

      beta_release.previous&.workflow_run&.cancel_workflow!
    end
  end

  def self.trigger_workflows(release_platform_run, commit)
    return if release_platform_run.tag_name.blank?
    return unless release_platform_run.train.trunk?

    beta_release = release_platform_run.beta_releases.find_by(commit: commit)
    WorkflowRun.create_and_trigger!(
      release_platform_run.conf.release_candidate_workflow,
      beta_release,
      commit,
      release_platform_run
    )
  end

  private

  def previous
    release_platform_run.latest_beta_release
  end

  def config
    release_platform_run.conf.beta_release.as_json
  end

  def rc_workflow_config
    release_platform_run.conf.release_candidate_workflow
  end

  attr_reader :release_platform_run, :build, :commit
  delegate :transaction, to: BetaRelease
end

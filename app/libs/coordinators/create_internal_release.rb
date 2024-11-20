class Coordinators::CreateInternalRelease
  def self.call(release_platform_run, commit)
    new(release_platform_run, commit).call

    if release_platform_run.release.release_platform_runs.all? { |run| run.internal_releases.exists?(commit: commit) } &&
        release_platform_run.train.trunk?

      tag_name = "v#{release_platform_run.release_version}"
      release_platform_run.train.create_tag!(tag_name, commit.commit_hash)

      release_platform_run.release.release_platform_runs.each do |run|
        run.update!(tag_name: tag_name)
      end
    end
  end

  def initialize(release_platform_run, commit)
    @release_platform_run = release_platform_run
    @commit = commit
  end

  def call
    return unless release_platform_run.on_track?

    transaction do
      release_platform_run.update_last_commit!(commit)
      release_platform_run.bump_version!
      release_platform_run.correct_version!
      internal_release = release_platform_run.internal_releases.create!(config:, previous:, commit:)
      WorkflowRun.create_and_trigger!(workflow_config, internal_release, commit, release_platform_run)
      internal_release.previous&.workflow_run&.cancel_workflow!
    end
  end

  def self.trigger_workflows(release_platform_run, commit)
    return if release_platform_run.tag_name.blank?
    return unless release_platform_run.train.trunk?

    internal_release = release_platform_run.internal_releases.find_by(commit: commit)
    WorkflowRun.create_and_trigger!(
      release_platform_run.conf.pick_internal_workflow,
      internal_release,
      commit,
      release_platform_run
    )
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

  delegate :transaction, to: InternalRelease
  attr_reader :release_platform_run, :commit
end

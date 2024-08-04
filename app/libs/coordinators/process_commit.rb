class Coordinators::ProcessCommit
  include Loggable

  def self.call(release, commit)
    new(release, commit).call
  end

  def initialize(release, commit)
    @release = release
    @commit = commit
  end

  delegate :train, to: :@release

  def call
    return @commit.add_to_build_queue! if @release.queue_commit?
    return unless @commit.applicable?

    # TODO: see if internal release is configured, if not, start beta release
    # TODO: change this to use the new have not started submission check
    @release.release_platform_runs.have_not_submitted_production.each do |run|
      trigger_internal_release_for(run)
    end
  rescue => e
    elog(e)
  end

  private

  def trigger_internal_release_for(release_platform_run)
    return if @release.hotfix?

    train.fixed_build_number? ? release_platform_run.bump_version_for_fixed_build_number! : release_platform_run.bump_version!
    release_platform_run.update!(last_commit: @commit)

    internal_release = release_platform_run.internal_releases.create!(
      config: release_platform_run.conf.internal_release,
      commit: @commit,
      previous: release_platform_run.latest_internal_release
    )
    internal_release.trigger_workflow!(release_platform_run.conf.workflows.pick_internal_workflow, @commit)
  end
end

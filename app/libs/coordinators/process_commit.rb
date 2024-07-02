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
      status: "created", # TODO: this should be a default for the column
      # FIXME: This is a temporary thing till we get actual config
      config: release_platform_run.internal_release_config
    )
    internal_release.trigger_workflow!(release_platform_run.release_platform.choose_workflow, @commit)
  end
end

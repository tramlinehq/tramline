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

    @release.release_platform_runs.have_not_submitted_production.each do |run|
      trigger_internal_release_for(run)
    end
  rescue => e
    elog(e)
  end

  private

  def trigger_internal_release_for(release_platform_run)
    return if @release.hotfix?
    return if release_platform_run.android?

    train.fixed_build_number? ? release_platform_run.bump_version_for_fixed_build_number! : release_platform_run.bump_version!
    release_platform_run.update!(last_commit: @commit)

    internal_release = release_platform_run.internal_releases.create!(
      status: "created",
      config: {auto_promote: true,
               distributions: [
                 {number: 1,
                  submission_type: "TestFlightSubmission",
                  submission_config: {id: :internal, name: "internal testing"},
                  rollout_config: {enabled: true, stages: [100]},
                  auto_promote: true}
               ]}
    )
    internal_release.trigger_workflow!(release_platform_run.release_platform.choose_workflow, @commit)
  end
end

class Coordinators::StartProductionRelease
  def self.call(release_platform_run, build_id)
    new(release_platform_run, build_id).call
  end

  def initialize(release_platform_run, build_id)
    @release_platform_run = release_platform_run
    @build = @release_platform_run.rc_builds.find(build_id)
  end

  def call
    with_lock do
      return unless release_platform_run.on_track?
      # return if release_platform_run.blocked_for_production_release?

      if current&.inflight?
        # If the latest production release is still inflight, attach the new RC build to it
        # and retrigger its submission, but only if the submission is in pre_review state
        submission = current.store_submission
        return if submission.blank?
        return unless submission.pre_review?

        return Coordinators::UpdateBuildOnProduction.call(submission, build.id)
      end

      # If this is an upcoming release starting production,
      # finalize the corresponding platform run in the ongoing release
      finalize_ongoing_release_platform_run!

      release_platform_run
        .production_releases
        .create!(build:, config:, previous: current, status: ProductionRelease::INITIAL_STATE)
        .trigger_submission!
    end
  end

  private

  def finalize_ongoing_release_platform_run!
    return unless release.upcoming?

    ongoing_release = train.ongoing_release
    return unless ongoing_release

    # Find the corresponding platform run in the ongoing release
    corresponding_run = ongoing_release.release_platform_runs.find_by(release_platform_id: release_platform_id)
    Coordinators::FinalizePlatformRun.call(corresponding_run)
  end

  def current
    release_platform_run.latest_production_release
  end

  def config
    release_platform_run.conf.production_release.as_json
  end

  attr_reader :release_platform_run, :build
  delegate :with_lock, :release, :train, :release_platform_id, to: :release_platform_run
end

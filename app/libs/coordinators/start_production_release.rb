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

      if previous&.inflight?
        # If the latest production release is still inflight, attach the new RC build to it
        # and retrigger its submission, but only if the submission is in pre_review state
        submission = previous.store_submission
        return if submission.blank?
        return unless submission.pre_review?

        return Coordinators::UpdateBuildOnProduction.call(submission, build.id)
      end

      release_platform_run
        .production_releases
        .create!(build:, config:, previous:, status: ProductionRelease::INITIAL_STATE)
        .trigger_submission!
    end
  end

  private

  def previous
    release_platform_run.latest_production_release
  end

  def config
    release_platform_run.conf.production_release.as_json
  end

  attr_reader :release_platform_run, :build
  delegate :with_lock, to: :release_platform_run
end

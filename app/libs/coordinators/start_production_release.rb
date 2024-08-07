class Coordinators::StartProductionRelease
  def self.call(build)
    new(build).call
  end

  def initialize(build)
    @build = build
    @release_platform_run = build.release_platform_run
  end

  delegate :android?, :ios?, to: :@release_platform_run
  delegate :transaction, to: ActiveRecord::Base

  def call
    transaction do
      return if previous&.active?

      @release_platform_run
        .production_releases
        .create!(build: @build, config: @release_platform_run.conf.production_release.value, previous:)
        .then { create_submission(_1) }
    end
  end

  def create_submission(parent_release)
    submission_config = parent_release.conf.submissions.first

    return @release_platform_run.play_store_submissions.create_and_trigger!(parent_release, submission_config, @build) if android?
    @release_platform_run.app_store_submissions.create_and_trigger!(parent_release, submission_config, @build) if ios?
  end

  private

  def previous
    @release_platform_run.latest_production_release
  end
end

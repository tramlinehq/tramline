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
      @release_platform_run
        .production_releases
        .create!(build: @build)
        .then { create_submission(_1) }
    end
  end

  def create_submission(parent_release)
    params = {
      release_platform_run: @release_platform_run,
      parent_release:,
      build: @build
    }

    return @release_platform_run.play_store_submissions.create!(params) if android?
    @release_platform_run.app_store_submissions.create!(params) if ios?
  end
end

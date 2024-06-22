class Coordinators::StartProductionRelease
  def self.call(release_platform_run, build)
    return unless release_platform_run.organization.product_v2?
    new(release_platform_run, build).call
  end

  def initialize(release_platform_run, build)
    @release_platform_run = release_platform_run
    @build = build
  end

  attr_reader :release_platform_run, :build
  delegate :android?, :ios?, to: :release_platform_run
  delegate :transaction, to: ActiveRecord::Base

  def call
    transaction do
      release = create_production_release
      submission = create_submission(release)
      create_rollout(submission)
    end
  end

  def create_production_release
    release_platform_run.production_releases.create!(build: build)
  end

  def create_submission(release)
    params = {
      release_platform_run: release_platform_run,
      production_release: release
    }

    return release_platform_run.play_store_submissions.create!(params) if android?
    release_platform_run.app_store_submissions.create!(params) if ios?
  end

  def create_rollout(submission)
    return unless submission.locked?

    params = {
      release_platform_run: release_platform_run,
      store_submission: submission
    }

    return release_platform_run.play_store_rollouts.create!(params) if android?
    release_platform_run.app_store_rollouts.create!(params) if ios?
  end
end

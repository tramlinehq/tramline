# frozen_string_literal: true

class V2::LiveRelease::InternalReleasesComponent < V2::BaseReleaseComponent
  include Memery

  SUBMISSION_STATUS = {
    created: {text: "Ongoing", status: :routine},
    failed: {text: "Failed", status: :failure},
    finished: {text: "Finished", status: :success}
  }

  def initialize(release)
    @release = release
    super(@release)
  end

  attr_reader :release

  def configured?(release_platform_run)
    configuration(release_platform_run).present?
  end

  memoize def configuration(release_platform_run)
    ReleaseConfig::Platform.new(release_platform_run.internal_release_config) if release_platform_run.internal_release_config.present?
  end

  memoize def internal_releases(release_platform_run)
    release_platform_run.internal_releases.order(created_at: :desc)
  end

  def previous_internal_release(release_platform_run)
    internal_releases(release_platform_run).drop(1).first
  end

  def latest_internal_release(release_platform_run)
    internal_releases(release_platform_run).first
  end

  def previous_internal_releases(release_platform_run)
    internal_releases(release_platform_run).drop(1)
  end

  def submission_status(submission)
    SUBMISSION_STATUS[submission.status.to_sym] || {text: submission.status.humanize, status: :neutral}
  end
end

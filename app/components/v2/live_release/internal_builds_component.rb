# frozen_string_literal: true

class V2::LiveRelease::InternalBuildsComponent < V2::BaseComponent
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

  def configuration(release_platform_run)
    release_platform_run.conf.internal_release
  end

  def internal_workflow_config(release_platform_run)
    release_platform_run.conf.workflows.pick_internal_workflow
  end

  def latest_internal_release(release_platform_run)
    release_platform_run.latest_internal_release
  end

  def previous_internal_releases(release_platform_run)
    release_platform_run.older_internal_releases
  end
end

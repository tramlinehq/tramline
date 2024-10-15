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
  end

  attr_reader :release

  def applicable_commit(run)
    run.release.last_applicable_commit
  end

  def configured?(run)
    configuration(run).present?
  end

  def internal_workflow_config(run)
    run.conf.pick_internal_workflow
  end

  def configuration(run)
    run.conf.internal_release
  end

  def latest_internal_release(run)
    run.latest_internal_release
  end

  def previous_internal_releases(run)
    run.older_internal_releases
  end

  memoize def builds(run)
    run.internal_builds.includes(:external_build)
  end
end

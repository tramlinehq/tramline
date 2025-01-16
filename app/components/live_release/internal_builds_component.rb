# frozen_string_literal: true

class LiveRelease::InternalBuildsComponent < BaseComponent
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

  def configuration(run)
    run.conf.internal_release
  end

  def latest_internal_release(run)
    run.latest_internal_release
  end

  def previous_internal_releases(run)
    run.older_internal_releases
  end
end

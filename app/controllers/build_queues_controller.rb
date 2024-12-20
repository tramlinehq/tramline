class BuildQueuesController < SignedInApplicationController
  around_action :set_time_zone
  before_action :require_write_access!, only: %i[apply]
  before_action :set_release, only: %i[apply]
  before_action :set_build_queue, only: %i[apply]

  def apply
    if (result = Action.apply_build_queue!(@build_queue)).ok?
      redirect_to changeset_tracking_release_path(@release), notice: "Build queue has been applied and emptied."
    else
      redirect_to current_release_path, flash: {error: t(".failure", errors: result.error.message)}
    end
  end

  private

  def already_triggered_error
    redirect_to current_release_path, flash: {error: "Cannot re-apply a build queue to a release!"}
  end

  def locked_release_error
    redirect_to current_release_path, flash: {error: "Cannot apply a build queue to a locked release."}
  end

  def ensure_release_platform_run
    if @release_platform_run.blank?
      redirect_to current_release_path, flash: {error: "Could not find the release!"}
    end
  end

  def set_build_queue
    @build_queue = BuildQueue.find(params[:id])
  end

  def set_release
    @release = Release.friendly.find(params[:release_id])
  end

  def current_release_path
    release_path(@release)
  end
end

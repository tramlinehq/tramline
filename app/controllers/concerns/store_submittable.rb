module StoreSubmittable
  def update
    build = @release_platform_run.rc_builds.find_by(id: submission_params[:build_id])
    redirect_back fallback_location: root_path, notice: t(".update.invalid_build") unless build

    if @submission.attach_build(build)
      redirect_back fallback_location: root_path, notice: t(".update.success")
    else
      redirect_back fallback_location: root_path, flash: {error: t(".update.failure", errors: @submission.display_attr(:failure_reason))}
    end
  end

  def prepare
    @submission.start_prepare!
    redirect_back fallback_location: root_path, notice: t(".prepare.success")
  end

  protected

  def submission_params
    params.require(:store_submission).permit(:build_id)
  end

  def set_release_platform_run
    @release_platform_run = @submission.release_platform_run
  end

  def ensure_actionable
    unless @submission.active_release?
      redirect_back fallback_location: root_path, flash: {error: t(".prepare.submission_not_active")}
    end
  end
end

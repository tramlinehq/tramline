module StoreSubmittable
  include Mocks::Sandboxable

  def update
    if (result = Coordinators::Signals.update_production_build!(@submission, build_id)).ok?
      redirect_back fallback_location: root_path, notice: t(".update.success")
    else
      redirect_back fallback_location: root_path, flash: {error: t(".update.failure", errors: result.error.message)}
    end
  end

  def prepare
    return mock_prepare_for_store if sandbox_mode?

    if (result = Coordinators::Signals.prepare_production_submission!(@submission)).ok?
      redirect_back fallback_location: root_path, notice: t(".prepare.success")
    else
      redirect_back fallback_location: root_path, flash: {error: t(".prepare.failure", errors: result.error.message)}
    end
  end

  protected

  def build_id
    params.require(:store_submission).permit(:build_id).fetch(:build_id)
  end

  def set_release_platform_run
    @release_platform_run = @submission.release_platform_run
  end

  def ensure_actionable
    unless @submission.actionable?
      redirect_back fallback_location: root_path, flash: {error: t(".prepare.submission_not_active")}
    end
  end
end

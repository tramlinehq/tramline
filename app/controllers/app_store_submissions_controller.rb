class AppStoreSubmissionsController < SignedInApplicationController
  include StoreSubmittable
  before_action :require_write_access!
  before_action :set_app_store_submission
  before_action :set_release_platform_run
  before_action :ensure_actionable
  before_action :ensure_reviewable, only: [:submit_for_review]
  before_action :ensure_cancellable, only: [:cancel]

  def submit_for_review
    return mock_submit_for_review_for_app_store if sandbox_mode?

    if (result = Action.start_production_review!(@submission)).ok?
      redirect_back fallback_location: root_path, notice: t(".submit_for_review.success")
    else
      redirect_back fallback_location: root_path, flash: {error: t(".submit_for_review.failure", errors: result.error.message)}
    end
  end

  def cancel
    return mock_cancel_review_for_app_store if sandbox_mode?

    if (result = Action.cancel_production_review!(@submission)).ok?
      redirect_back fallback_location: root_path, notice: t(".cancel.success")
    else
      redirect_back fallback_location: root_path, flash: {error: t(".cancel.failure", errors: result.error.message)}
    end
  end

  private

  def ensure_cancellable
    unless @submission.may_start_cancellation?
      redirect_back fallback_location: root_path, flash: {error: t(".cancel.uncanceleable")}
    end
  end

  def ensure_reviewable
    unless @submission.reviewable?
      redirect_back fallback_location: root_path, flash: {error: t(".submit_for_review.unreviewable")}
    end
  end

  def set_app_store_submission
    @submission = AppStoreSubmission.find_by(id: params[:id])
  end
end

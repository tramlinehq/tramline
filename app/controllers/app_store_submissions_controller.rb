class AppStoreSubmissionsController < SignedInApplicationController
  include StoreSubmittable
  before_action :require_write_access!
  before_action :set_app_store_submission
  before_action :set_release_platform_run
  before_action :ensure_reviewable, only: [:submit_for_review]
  before_action :ensure_cancellable, only: [:cancel]

  def submit_for_review
    @submission.start_submission!

    if @submission.failed?
      redirect_back fallback_location: root_path, flash: {error: t(".submit_for_review.failure", errors: @submission.display_attr(:failure_reason))}
    else
      redirect_back fallback_location: root_path, notice: t(".submit_for_review.success")
    end
  end

  def cancel
    @submission.start_cancellation!

    if @submission.failed?
      redirect_back fallback_location: root_path, flash: {error: t(".cancel.failure", errors: @submission.display_attr(:failure_reason))}
    else
      redirect_back fallback_location: root_path, notice: t(".cancel.success")
    end
  end

  def prepare
    @submission.start_prepare!(force: true)

    redirect_back fallback_location: root_path, notice: t(".prepare.success")
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

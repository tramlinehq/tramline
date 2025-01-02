class StoreSubmissionsController < SignedInApplicationController
  # include Mocks::Sandboxable
  include Tabbable

  before_action :require_write_access!, except: [:index]
  before_action :set_submission
  before_action :ensure_triggerable, only: [:trigger]
  before_action :ensure_actionable, only: [:update, :prepare, :submit_for_review, :cancel]
  before_action :ensure_retryable, only: [:retry]
  before_action :ensure_reviewable, only: [:submit_for_review]
  before_action :ensure_cancellable, only: [:cancel]
  before_action :live_release!, only: %i[index]
  before_action :set_app, only: %i[index]
  around_action :set_time_zone

  def index
  end

  def trigger
    # return mock_trigger_submission if sandbox_mode?
    if (result = Action.trigger_submission!(@submission)).ok?
      redirect_back fallback_location: fallback_path, notice: t(".success")
    else
      redirect_back fallback_location: fallback_path, flash: {error: t(".failure", errors: result.error.message)}
    end
  end

  def fully_release_previous_rollout
    if (res = Action.fully_release_the_previous_rollout!(@submission)).ok?
      redirect_back fallback_location: root_path, notice: t(".success")
    else
      redirect_back fallback_location: root_path, flash: {error: t(".failure", errors: res.error.message)}
    end
  end

  def submit_for_review
    # return mock_submit_for_review_for_app_store if sandbox_mode?
    if (result = Action.start_production_review!(@submission)).ok?
      redirect_back fallback_location: fallback_path, notice: t(".submit_for_review.success")
    else
      redirect_back fallback_location: fallback_path, flash: {error: t(".submit_for_review.failure", errors: result.error.message)}
    end
  end

  def cancel
    # return mock_cancel_review_for_app_store if sandbox_mode?
    if (result = Action.cancel_production_review!(@submission)).ok?
      redirect_back fallback_location: fallback_path, notice: t(".cancel.success")
    else
      redirect_back fallback_location: fallback_path, flash: {error: t(".cancel.failure", errors: result.error.message)}
    end
  end

  def update
    # return mock_update_production_build(build_id) if sandbox_mode?
    if (result = Action.update_production_build!(@submission, build_id)).ok?
      redirect_back fallback_location: fallback_path, notice: t(".update.success")
    else
      redirect_back fallback_location: fallback_path, flash: {error: t(".update.failure", errors: result.error.message)}
    end
  end

  def prepare
    # return mock_prepare_for_store if sandbox_mode?
    if (result = Action.prepare_production_submission!(@submission)).ok?
      redirect_back fallback_location: fallback_path, notice: t(".prepare.success")
    else
      redirect_back fallback_location: fallback_path, flash: {error: t(".failure", errors: result.error.message)}
    end
  end

  def retry
    if (result = Action.retry_submission!(@submission)).ok?
      redirect_back fallback_location: fallback_path, notice: t(".success")
    else
      redirect_back fallback_location: fallback_path, flash: {error: t(".failure", errors: result.error.message)}
    end
  end

  protected

  def build_id
    params.require(:store_submission).permit(:build_id).fetch(:build_id)
  end

  def set_submission
    @submission = StoreSubmission.find_by(id: params[:id])
  end

  def set_app
    @app = @release.app
  end

  def ensure_actionable
    unless @submission.actionable?
      redirect_back fallback_location: root_path, flash: {error: t(".submission_not_active")}
    end
  end

  def ensure_retryable
    unless @submission.retryable?
      redirect_back fallback_location: root_path, flash: {error: t(".submission_not_retryable")}
    end
  end

  def ensure_triggerable
    unless @submission.triggerable?
      redirect_back fallback_location: fallback_path, flash: {error: t(".trigger.failure")}
    end
  end

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

  def fallback_path
    overview_release_path(@submission.release)
  end
end

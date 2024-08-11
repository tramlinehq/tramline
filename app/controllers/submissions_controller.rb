class SubmissionsController < SignedInApplicationController
  include Mocks::Sandboxable

  before_action :require_write_access!
  before_action :set_submission
  before_action :ensure_triggerable, only: [:trigger]

  def trigger
    return mock_trigger_submission if sandbox_mode?

    if (result = Action.trigger_submission!(@submission)).ok?
      redirect_back fallback_location: fallback_path, notice: t(".trigger.success")
    else
      redirect_back fallback_location: fallback_path, flash: {error: t(".trigger.failure", errors: result.error.message)}
    end
  end

  def retry
    raise NotImplementedError
  end

  protected

  def set_submission
    @submission = StoreSubmission.find_by(id: params[:id])
  end

  def ensure_triggerable
    unless @submission.triggerable?
      redirect_back fallback_location: fallback_path, flash: {error: t(".trigger.failure")}
    end
  end

  def fallback_path
    overview_release_path(@submission.release)
  end
end

class SubmissionsController < SignedInApplicationController
  before_action :require_write_access!
  before_action :set_submission
  before_action :ensure_triggerable, only: [:trigger]

  def trigger
    @submission.trigger!
    redirect_back fallback_location: fallback_path, notice: t(".trigger.success")
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

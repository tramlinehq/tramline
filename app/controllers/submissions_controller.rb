class SubmissionsController < SignedInApplicationController
  before_action :require_write_access!
  before_action :set_submission

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

  def fallback_path
    overview_release_path(@submission.release)
  end
end

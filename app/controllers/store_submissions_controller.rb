class StoreSubmissionsController < SignedInApplicationController
  before_action :require_write_access!
  before_action :set_release
  before_action :set_release_platform
  before_action :set_release_platform_run
  before_action :set_store_submission, only: [:update, :prepare, :submit_for_review, :cancel]
  before_action :ensure_reviewable, only: [:submit_for_review]
  before_action :ensure_cancellable, only: [:cancel]
  before_action :ensure_preparable, only: [:prepare]

  def create
    build = @release_platform_run.builds.find_by(id: submission_params[:build_id])

    redirect_back fallback_location: root_path, notice: t(".create.invalid_build") unless build

    submission = @release_platform_run.store_submissions.new
    submission.attach_build!(build)
    submission.save!

    redirect_back fallback_location: root_path, notice: t(".create.success")
  end

  def update
    build = @release_platform_run.builds.find_by(id: submission_params[:build_id])

    redirect_back fallback_location: root_path, notice: t(".update.invalid_build") unless build

    if @submission.attach_build!(build)
      @submission.start_prepare!(force: true)
      redirect_back fallback_location: root_path, notice: t(".update.success")
    else
      redirect_back fallback_location: root_path, flash: {error: t(".update.failure", errors: @submission.display_attr(:failure_reason))}
    end
  end

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

  def submission_params
    params.require(:store_submission).permit(:build_id, :force)
  end

  def ensure_cancellable
    unless @submission.cancelable?
      redirect_back fallback_location: root_path, flash: {error: t(".cancel.uncanceleable")}
    end
  end

  def ensure_reviewable
    unless @submission.reviewable?
      redirect_back fallback_location: root_path, flash: {error: t(".submit_for_review.unreviewable")}
    end
  end

  def ensure_preparable
    unless @submission.startable?
      redirect_back fallback_location: root_path, flash: {error: t(".prepare.unstartable")}
    end
  end

  def set_release
    @release = Release.friendly.find(params[:release_id])
  end

  def set_release_platform
    @release_platform = @release.release_platforms.friendly.find_by(platform: params[:platform_id])
  end

  def set_release_platform_run
    @release_platform_run = @release.release_platform_runs.find_by(release_platform: @release_platform)
  end

  def set_store_submission
    @submission = @release_platform_run.store_submissions.find_by(id: params[:id])
  end
end

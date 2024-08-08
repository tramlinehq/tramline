module Mocks::Sandboxable
  include Sandboxable
  NotInSandboxModeError = Class.new(StandardError)

  def mock_trigger_submission
    ensure_sandboxable
    @submission.mock_trigger!
    redirect_back fallback_location: root_path, notice: t(".trigger.success")
  end

  def mock_prepare_for_store
    ensure_sandboxable
    @submission.mock_prepare_for_release_for_app_store!
    redirect_back fallback_location: root_path, notice: t(".prepare.success")
  end

  def mock_submit_for_review_for_app_store
    ensure_sandboxable
    @submission.mock_submit_for_review_for_app_store!
    redirect_back fallback_location: root_path, notice: t(".submit_for_review.success")
  end

  def mock_approve_for_app_store
    ensure_sandboxable
    @submission.mock_approve_for_app_store!
    redirect_back fallback_location: root_path
  end

  def mock_reject_for_app_store
    ensure_sandboxable
    @submission.mock_reject_for_app_store!
    redirect_back fallback_location: root_path
  end

  def ensure_sandboxable
    raise NotInSandboxModeError unless sandbox_mode?
  end
end

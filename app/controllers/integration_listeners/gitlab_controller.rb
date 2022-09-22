class IntegrationListeners::GitlabController < IntegrationListenerController
  skip_before_action :verify_authenticity_token, only: [:events]
  skip_before_action :require_login, only: [:events]

  def events
    Rails.logger.info params
  end

  def providable_params
    super.merge(code: code)
  end
end

class IntegrationListeners::GitlabController < IntegrationListenerController
  def providable_params
    super.merge(code: code)
  end
end

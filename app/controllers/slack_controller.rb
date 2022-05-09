class SlackController < IntegrationListenerController
  def providable_params
    super.merge({
      code: code
    })
  end
end

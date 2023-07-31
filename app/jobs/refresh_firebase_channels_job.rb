class RefreshFirebaseChannelsJob < ApplicationJob
  include Loggable
  queue_as :high

  def perform(fad_integration_id)
    fad_integration = GoogleFirebaseIntegration.find(fad_integration_id)
    return unless fad_integration

    fad_integration.populate_channels!
  end
end

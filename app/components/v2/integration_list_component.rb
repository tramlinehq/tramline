class V2::IntegrationListComponent < V2::BaseComponent
  def initialize(app, integrations)
    @app = app
    @integrations_by_categories = integrations
  end

  def connected_integrations?(integrations)
    integrations.any? { |i| i.connected? && i.providable.further_setup? }
  end
end

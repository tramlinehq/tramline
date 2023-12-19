class V2::IntegrationListComponent < V2::BaseComponent
  def initialize(app, integrations)
    @app = app
    @integrations_by_categories = integrations
  end
end

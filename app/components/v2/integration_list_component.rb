class V2::IntegrationListComponent < V2::BaseComponent
  def initialize(app, integrations, pre_open_category: nil)
    @app = app
    @integrations_by_categories = integrations
    @pre_open_category = pre_open_category
  end

  def title(category)
    "Configure #{Integration.human_enum_name(:category, category)}"
  end

  def pre_open?(category)
    @pre_open_category == category
  end

  def connected_integrations?(integrations)
    integrations.any? { |i| i.connected? && i.providable.further_setup? }
  end
end

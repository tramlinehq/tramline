class IntegrationListComponent < BaseComponent
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
    # TODO: Move away from checking integration category later
    integrations.any? { |i| i.connected? && i.further_setup? && !(i.version_control? || i.ci_cd?) }
  end
end

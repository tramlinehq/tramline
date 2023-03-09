module DeploymentsHelper
  def show_deployment(deployment)
    display = deployment.display_attr(:integration_type)
    display += " • #{deployment.build_artifact_channel["name"]}" unless deployment.external?
    display
  end
end

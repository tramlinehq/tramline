module DeploymentsHelper
  def show_deployment(deployment)
    display = deployment.display_attr(:integration_type)
    display += " • #{deployment.build_artifact_channel["name"]}" if deployment.display_channel?
    display
  end
end

module DeploymentsHelper
  def deployment_channel_name(chan)
    chan["is_internal"] ? chan["name"] + " (Internal)" : chan["name"]
  end

  def show_deployment(deployment)
    display = deployment.display_attr(:integration_type)
    display += " • #{deployment_channel_name(deployment.build_artifact_channel)}" if deployment.display_channel?
    display
  end
end

module DeploymentsHelper
  def show_deployment(deployment)
    if deployment.external?
      "External (outside Tramline)"
    else
      "#{deployment.integration.providable.display} • #{deployment.build_artifact_channel["name"]}"
    end
  end

  def deployment_integration_name(deployment)
    if deployment.external?
      "external"
    else
      deployment.integration.providable.to_s
    end
  end
end

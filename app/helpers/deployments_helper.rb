module DeploymentsHelper
  def show_deployment_provider(deployment)
    if deployment.external?
      "External (outside Tramline)"
    else
      deployment.integration.providable.display
    end
  end

  def show_deployment_channel(deployment)
    deployment.build_artifact_channel["name"]
  end

  def deployment_integration_name(deployment)
    if deployment.external?
      "external"
    else
      deployment.integration.providable.to_s
    end
  end
end

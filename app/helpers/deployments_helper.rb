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

  def deployment_external_integration_name(deployment)
    Deployment.human_attr_value(:integration_type, deployment.integration_type)
  end
end

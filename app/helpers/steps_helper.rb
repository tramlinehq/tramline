module StepsHelper
  def show_deployment_provider(step)
    step.build_artifact_integration.gsub("Integration", "").titleize
  end

  def show_deployment_channel(step)
    step.build_artifact_channel.values.first
  end

  def show_ci_cd_provider(step)
    step.app.ci_cd_provider.class.name.gsub("Integration", "").titleize
  end

  def show_ci_cd_channel(step)
    step.ci_cd_channel.values.first
  end
end

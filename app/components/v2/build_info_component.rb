class V2::BuildInfoComponent < V2::BaseComponent
  def initialize(deployment_run)
    @deployment_run = deployment_run
    @step_run = deployment_run&.step_run
  end

  delegate :step, to: :@step_run
  delegate :deployment, to: :@deployment_run
  delegate :integration, to: :deployment

  def build_info
    "#{@step_run.build_version} (#{@step_run.build_number})"
  end

  def ci_info
    @step_run.commit.short_sha
  end

  def build_deployed_at
    ago_in_words @deployment_run.updated_at
  end

  def build_logo
    "integrations/logo_#{step.ci_cd_provider}.png"
  end

  def deployment_logo
    "integrations/logo_#{deployment.integration_type}.png"
  end
end

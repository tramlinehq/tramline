class ReleaseMonitoringComponent < ViewComponent::Base
  attr_reader :platform_run

  delegate :adoption_rate, :errors_count, :new_errors_count, to: :release_data
  delegate :app, to: :platform_run
  delegate :monitoring_provider, to: :app

  def initialize(platform_run:)
    @platform_run = platform_run
  end

  def monitoring_provider_url
    monitoring_provider.project_url
  end

  def store_provider
    production_deployment_run.integration.providable
  end

  def release_data
    @release_data ||= production_deployment_run&.latest_health_data
  end

  def release_step_run
    @release_step_run ||= platform_run.last_run_for(platform_run.release_platform.release_step)
  end

  def production_deployment_run
    @production_deployment_run ||= release_step_run.deployment_runs.reached_production.first
  end

  def staged_rollout
    @staged_rollout ||= production_deployment_run.staged_rollout
  end

  def staged_rollout_percentage
    staged_rollout.last_rollout_percentage
  end

  def staged_rollout_text
    return "Fully Released" if staged_rollout.fully_released?
    "Stage #{staged_rollout.display_current_stage} of #{staged_rollout.config.size}"
  end

  def user_stability
    return "-" if release_data.user_stability.blank?
    "#{release_data.user_stability}%"
  end

  def session_stability
    return "-" if release_data.session_stability.blank?
    "#{release_data.session_stability}%"
  end
end

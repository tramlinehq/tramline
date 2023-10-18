class ReleaseMonitoringComponent < ViewComponent::Base
  attr_reader :platform_run

  delegate :adoption_rate, :errors, :new_errors, :session_stability, :user_stability, to: :release_data

  def initialize(platform_run:)
    @platform_run = platform_run
  end

  def monitoring_source
    platform_run.app.monitoring_provider.to_s
  end

  def store_source
    production_deployment_run.integration.provider.to_s
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
    return "-" if user_stability.blank?
    "#{user_stability}%"
  end

  def session_stability
    return "-" if session_stability.blank?
    "#{session_stability}%"
  end
end

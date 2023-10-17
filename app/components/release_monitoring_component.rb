class ReleaseMonitoringComponent < ViewComponent::Base
  attr_reader :platform_run

  def initialize(platform_run:)
    @platform_run = platform_run
  end

  def release_data
    @metrics ||= platform_run.health_data
  end

  def current_release_step
    @release_step_run ||= platform_run.last_successful_run_for(platform_run.release_platform.release_step)
  end

  def current_production_deployment
    @deployment_run ||= current_release_step.deployment_runs.reached_production.first
  end

  def current_staged_rollout
    @staged_rollout ||= current_production_deployment.staged_rollout
  end

  def staged_rollout_percentage
    current_staged_rollout.last_rollout_percentage
  end

  def staged_rollout_text
    return "Fully Released" if current_staged_rollout.fully_released?
    "Stage #{current_staged_rollout.display_current_stage} of #{current_staged_rollout.config.size}"
  end

  def new_errors_count
    release_data["errors_introduced_count"]
  end

  def errors_count
    release_data["errors_seen_count"]
  end

  def sessions_count_in_last_24h
    release_data["sessions_count_in_last_24h"]
  end

  def sessions
    release_data["total_sessions_count"]
  end

  def sessions_with_errors
    release_data["unhandled_sessions_count"]
  end

  def daily_users
    release_data["accumulative_daily_users_seen"]
  end

  def daily_users_with_errors
    release_data["accumulative_daily_users_with_unhandled"]
  end

  def user_stability
    return "0%" if daily_users.zero?
    "#{((1 - (daily_users_with_errors.to_f / daily_users.to_f)) * 100).ceil(2)}%"
  end

  def session_stability
    return "0%" if sessions.zero?
    "#{((1 - (sessions_with_errors.to_f / sessions.to_f)) * 100).ceil(2)}%"
  end

  def adoption_rate
    sessions_count_in_last_24h / sessions
  end

  def errors
    platform_run.top_errors
  end

  def new_errors
    platform_run.top_new_errors
  end
end

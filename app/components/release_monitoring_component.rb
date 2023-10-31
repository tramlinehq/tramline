class ReleaseMonitoringComponent < ViewComponent::Base
  attr_reader :deployment_run

  delegate :adoption_rate, :errors_count, :new_errors_count, to: :release_data
  delegate :app, to: :deployment_run
  delegate :monitoring_provider, to: :app

  def initialize(deployment_run:)
    @deployment_run = deployment_run
  end

  def build_identifier
    "#{deployment_run.build_version} (#{deployment_run.build_number})"
  end

  def monitoring_provider_url
    monitoring_provider.dashboard_url(deployment_run.platform)
  end

  def store_provider
    deployment_run.integration.providable
  end

  def release_data
    @release_data ||= deployment_run&.latest_health_data
  end

  def staged_rollout
    @staged_rollout ||= deployment_run.staged_rollout
  end

  def staged_rollout_percentage
    staged_rollout&.last_rollout_percentage || Deployment::FULL_ROLLOUT_VALUE
  end

  def staged_rollout_text
    return "Fully Released" unless staged_rollout
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

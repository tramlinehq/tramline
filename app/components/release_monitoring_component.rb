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

  def adoption_chart_data
    @chart_data ||= deployment_run
      .release_health_metrics
      .group_by_day(:fetched_at, last: 10)
      .maximum("round(CAST(sessions_in_last_day::float * 100 / total_sessions_in_last_day::float as numeric), 2)")
      .compact
      .map { |k, v| [k.strftime("%d %b"), {adoption_rate: v, rollout_percentage: deployment_run.rollout_percentage_at(k)}] }
      .to_h

    return unless @chart_data.keys.size >= 2

    {
      data: @chart_data,
      type: "line",
      value_format: "number",
      name: "release_health.adoption_rate"
    }
  end
end

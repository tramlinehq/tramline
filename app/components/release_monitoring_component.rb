class ReleaseMonitoringComponent < ViewComponent::Base
  include AssetsHelper
  include ApplicationHelper
  attr_reader :deployment_run

  delegate :adoption_rate, to: :release_data
  delegate :app, :release_health_rules, to: :deployment_run
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

  def events
    @deployment_run.release_health_events.last(3).map do |event|
      type = event.healthy? ? :success : :error
      title = event.healthy? ? "Rule is healthy" : "Rule is unhealthy"
      {
        timestamp: time_format(event.event_timestamp, with_year: false),
        title:,
        description: event.description,
        type:
      }
    end
  end

  def release_healthy?
    @is_healthy ||= @deployment_run.healthy?
  end

  def release_health
    return "Healthy" if release_healthy?
    "Unhealthy"
  end

  def release_health_class
    return "text-green-800" if release_healthy?
    "text-red-800"
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
    value = release_data.user_stability.blank? ? "-" : "#{release_data.user_stability}%"
    {value:, is_healthy: release_data.metric_healthy?("user_stability")}
  end

  def session_stability
    value = release_data.session_stability.blank? ? "-" : "#{release_data.session_stability}%"
    {value:, is_healthy: release_data.metric_healthy?("session_stability")}
  end

  def errors_count
    value = release_data.errors_count
    {value:, is_healthy: release_data.metric_healthy?("errors")}
  end

  def new_errors_count
    value = release_data.new_errors_count
    {value:, is_healthy: release_data.metric_healthy?("new_errors")}
  end

  def adoption_chart_data
    return unless release_data
    range_end = release_data.fetched_at
    range_start = deployment_run.created_at
    @chart_data ||= deployment_run
      .release_health_metrics
      .group_by_day(:fetched_at, range: range_start..range_end)
      .maximum("round(CAST(sessions_in_last_day::float * 100 / total_sessions_in_last_day::float as numeric), 2)")
      .compact
      .map { |k, v| [k.strftime("%d %b"), {adoption_rate: v, rollout_percentage: deployment_run.rollout_percentage_at(k)}] }
      .last(10)
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

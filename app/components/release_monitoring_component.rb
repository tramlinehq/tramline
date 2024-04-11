class ReleaseMonitoringComponent < V2::BaseComponent
  METRICS = [:staged_rollout, :adoption_rate, :adoption_chart, :errors, :stability]

  SIZES = {
    sm: {cols: 2, size: 4}
  }

  def initialize(deployment_run:, metrics: METRICS, show_version_info: true, cols: 2, size: :base, num_events: 3)
    raise ArgumentError, "metrics must be one of #{METRICS}" unless (metrics - METRICS).empty?

    @deployment_run = deployment_run
    @metrics = metrics
    @show_version_info = show_version_info
    @cols = cols
    @size = size
    @num_events = num_events
  end

  delegate :adoption_rate, to: :release_data, allow_nil: true
  delegate :app, :release_health_rules, :platform, :external_link, to: :deployment_run
  delegate :monitoring_provider, to: :app
  delegate :current_user, to: :helpers

  attr_reader :deployment_run, :metrics, :show_version_info, :size

  def empty_component?
    release_data.blank?
  end

  def build_identifier
    "#{deployment_run.build_version} (#{deployment_run.build_number})"
  end

  def monitoring_provider_url
    monitoring_provider.dashboard_url(platform:, release_id: release_data&.external_release_id)
  end

  def store_provider
    deployment_run.integration.providable
  end

  def release_data
    @release_data ||= deployment_run&.latest_health_data
  end

  def staged_rollout
    @staged_rollout ||= deployment_run&.staged_rollout
  end

  def events
    deployment_run.release_health_events.reorder("event_timestamp DESC").first(@num_events).map do |event|
      type = event.healthy? ? :success : :error
      rule_health = event.healthy? ? "healthy" : "unhealthy"
      {
        timestamp: time_format(event.event_timestamp, with_year: false),
        title: "#{event.release_health_rule.name} is #{rule_health}",
        description: event_description(event),
        type:
      }
    end
  end

  def event_description(event)
    metric = event.release_health_metric
    triggers = event.release_health_rule.triggers
    status = event.health_status
    triggers.map do |expr|
      value = metric.evaluate(expr.metric)
      is_healthy = expr.evaluate(value) if value
      "#{expr.display_attr(:metric)} (#{value}) #{expr.describe_comparator(status)} the threshold value (#{expr.threshold_value})" if is_healthy
    end.compact.join(", ")
  end

  def release_healthy?
    @is_healthy ||= deployment_run.healthy?
  end

  def release_health
    return "Not Available" if release_data.blank?
    return "Healthy" if release_healthy?
    "Unhealthy"
  end

  def health_status_duration
    last_event = deployment_run.release_health_events.reorder("event_timestamp DESC").first
    return unless last_event
    ago_in_words(last_event.event_timestamp, prefix: "since", suffix: nil)
  end

  def release_health_class
    return "text-main-600" if release_data.blank?
    return "text-green-800" if release_healthy?
    "text-red-800"
  end

  def staged_rollout_percentage
    deployment_run.rollout_percentage
  end

  def staged_rollout_text
    return "Fully Released" unless staged_rollout
    return "Fully Released" if staged_rollout.fully_released?
    "Stage #{staged_rollout.display_current_stage} of #{staged_rollout.config.size}"
  end

  def user_stability
    value = release_data.user_stability.blank? ? "-" : "#{release_data.user_stability}%"
    {
      value:,
      is_healthy: release_data.metric_healthy?("user_stability"),
      rule: release_data.rule_for_metric("user_stability")
    }
  end

  def session_stability
    value = release_data.session_stability.blank? ? "-" : "#{release_data.session_stability}%"
    {
      value:,
      is_healthy: release_data.metric_healthy?("session_stability"),
      rule: release_data.rule_for_metric("session_stability")
    }
  end

  def errors_count
    value = release_data.errors_count
    {
      value:,
      is_healthy: release_data.metric_healthy?("errors_count"),
      rule: release_data.rule_for_metric("errors_count")
    }
  end

  def new_errors_count
    value = release_data.new_errors_count
    {
      value:,
      is_healthy: release_data.metric_healthy?("new_errors_count"),
      rule: release_data.rule_for_metric("new_errors_count")
    }
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

  def grid_cols
    "grid-cols-#{@cols}"
  end

  def full_span
    "col-span-#{@cols}"
  end
end

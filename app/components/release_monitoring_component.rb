class ReleaseMonitoringComponent < BaseComponent
  METRICS = [:staged_rollout, :adoption_rate, :adoption_chart, :errors, :stability]
  SIZES = {
    compact: {cols: 2},
    default: {cols: 3},
    max: {cols: 4}
  }

  def initialize(store_rollout:, metrics: METRICS, size: :default, num_events: 3)
    raise ArgumentError, "metrics must be one of #{METRICS}" unless (metrics - METRICS).empty?

    @store_rollout = store_rollout
    @metrics = metrics
    @size = size
    @cols = SIZES[@size][:cols]
    @num_events = num_events
  end

  delegate :adoption_rate, to: :release_data, allow_nil: true
  delegate :monitoring_provider, :platform, :release_health_rules, :show_health?, :release_health_events, :app, :train, to: :parent_release
  delegate :parent_release, :store_submission, :last_rollout_percentage, :provider, to: :store_rollout
  delegate :current_user, to: :helpers
  delegate :store_link, to: :store_submission

  attr_reader :store_rollout, :metrics, :size

  def multi_provider?
    connected_provider_types.size > 1
  end

  def provider_health_data
    @provider_health_data ||= begin
      # Only show providers that are currently connected. Historical metrics from
      # a provider that was later disconnected stay in the table but must not
      # render their own section. Every connected provider gets a slot; ones
      # without any metric yet are surfaced with a nil value so the view can
      # render a "waiting for data" state for them.
      by_type = parent_release
        .latest_health_data_by_provider
        .index_by(&:monitoring_provider_type)
      connected_provider_types.index_with { |provider_type| by_type[provider_type] }
    end
  end

  def provider_display_name(provider_type)
    provider_type&.demodulize&.chomp("Integration")&.titleize || "Unknown"
  end

  def provider_icon(provider_type)
    name = provider_type&.demodulize&.chomp("Integration")&.downcase
    name.presence || "external"
  end

  def provider_dashboard_url(provider_type, data)
    prov = resolve_provider(provider_type)
    return if prov.blank?
    prov.dashboard_url(platform:, release_id: data&.external_release_id)
  end

  def empty_component?
    release_data.blank?
  end

  def monitoring_provider_url
    monitoring_provider&.dashboard_url(platform:, release_id: release_data&.external_release_id)
  end

  def release_data
    @release_data ||= parent_release.latest_health_data
  end

  def staged_rollout_text
    return "Fully Released" unless store_rollout.is_staged_rollout?
    return "Fully Released" if store_rollout.fully_released?
    "Stage #{store_rollout.stage} of #{store_rollout.config.size}"
  end

  def user_stability
    value = release_data.user_stability.blank? ? "-" : "#{release_data.user_stability}%"
    metric_data("user_stability", value)
  end

  def session_stability
    value = release_data.session_stability.blank? ? "-" : "#{release_data.session_stability}%"
    metric_data("session_stability", value)
  end

  def errors_count
    return if release_data&.errors_count.blank?
    metric_data("errors_count", release_data.errors_count)
  end

  def new_errors_count
    return if release_data&.new_errors_count.blank?
    metric_data("new_errors_count", release_data.new_errors_count)
  end

  def adoption_chart_data
    return unless release_data
    range_end = release_data.fetched_at
    range_start = store_rollout.created_at
    metrics_scope = parent_release.release_health_metrics
    # Scope to a single provider: sessions from different providers are not comparable,
    # so mixing them into one series would produce meaningless adoption numbers.
    metrics_scope = metrics_scope.where(monitoring_provider_type: primary_provider_type) if primary_provider_type.present?
    @chart_data ||= metrics_scope
      .group_by_day(:fetched_at, range: range_start..range_end)
      .maximum("CASE WHEN total_sessions_in_last_day = 0 THEN 0
                     ELSE round(CAST(sessions_in_last_day::float * 100 / total_sessions_in_last_day::float as numeric), 2)
                END")
      .compact
      .map { |k, v| [k.strftime("%d %b"), {adoption_rate: v, rollout_percentage: store_rollout.rollout_percentage_at(k)}] }
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

  def show_release_health?
    release_health_rules.present? && show_health?
  end

  def events
    release_health_events.reorder("event_timestamp DESC").first(@num_events).map do |event|
      type = event.healthy? ? :success : :error
      rule_health = event.healthy? ? "healthy" : "unhealthy"
      {
        timestamp: time_format(event.event_timestamp, with_year: false),
        title: "#{event.release_health_rule.display_name} is #{rule_health}",
        description: event_description(event),
        type:
      }
    end
  end

  def event_description(event)
    return if event.healthy?
    metric = event.release_health_metric
    triggers = event.release_health_rule.triggers
    triggers.filter_map do |expr|
      value = metric.evaluate(expr.metric)
      expr.evaluation(value) => { is_healthy:, expression: }
      expression unless is_healthy
    end.join(", ")
  end

  def release_healthy?
    @is_healthy ||= parent_release.healthy?
  end

  def release_health
    return "Not Available" if release_data.blank?
    return "Healthy" if release_healthy?
    "Unhealthy"
  end

  def health_status_duration
    last_event = release_health_events.reorder("event_timestamp DESC").first
    return unless last_event
    ago_in_words(last_event.event_timestamp, prefix: "since", suffix: nil)
  end

  def release_health_class
    return "text-main-600" if release_data.blank?
    return "text-green-800" if release_healthy?
    "text-red-800"
  end

  def user_stability_for(data)
    value = data.user_stability.blank? ? "-" : "#{data.user_stability}%"
    metric_data_for(data, "user_stability", value)
  end

  def session_stability_for(data)
    value = data.session_stability.blank? ? "-" : "#{data.session_stability}%"
    metric_data_for(data, "session_stability", value)
  end

  def errors_count_for(data)
    return if data.errors_count.blank?
    metric_data_for(data, "errors_count", data.errors_count)
  end

  def new_errors_count_for(data)
    return if data.new_errors_count.blank?
    metric_data_for(data, "new_errors_count", data.new_errors_count)
  end

  private

  # Class names of the app's currently-connected monitoring providers
  # (Integration#monitoring_providers already excludes discarded/disconnected).
  def connected_provider_types
    @connected_provider_types ||= app.monitoring_providers.map { |provider| provider.class.name }
  end

  def primary_provider_type
    @primary_provider_type ||= monitoring_provider&.class&.name
  end

  def resolve_provider(provider_type)
    providers = parent_release.app.monitoring_providers
    return monitoring_provider if providers.blank?
    klass = provider_type&.safe_constantize
    (klass && providers.find { |p| p.instance_of?(klass) }) || monitoring_provider
  end

  def metric_data_for(data, metric_name, value)
    {
      value:,
      is_healthy: data.metric_healthy?(metric_name),
      rules: data.rules_for_metric(metric_name)
    }
  end

  def metric_data(metric_name, value)
    {
      value:,
      is_healthy: release_data.metric_healthy?(metric_name),
      rules: release_data.rules_for_metric(metric_name)
    }
  end
end

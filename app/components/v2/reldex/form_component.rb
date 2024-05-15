class V2::Reldex::FormComponent < V2::Reldex::BaseComponent
  def initialize(release_index)
    @release_index = release_index
  end

  attr_reader :release_index
  delegate :train, to: :release_index
  delegate :app, to: :train

  def components
    release_index.components.order(weight: :desc)
  end

  TOLERANCE_RANGES = {
    hotfixes: {allowed_range: 0..5, step: 1},
    rollout_fixes: {allowed_range: 0..10, step: 1},
    rollout_duration: {allowed_range: 0..30, step: 1},
    duration: {allowed_range: 0..30, step: 1},
    stability_duration: {allowed_range: 0..20, step: 1},
    stability_changes: {allowed_range: 0..50, step: 1},
    rollout_changes: {allowed_range: 0..20, step: 1},
    days_since_last_release: {allowed_range: 0..30, step: 1}
  }

  def base_form_config
    {from_method: :tolerable_min,
     to_method: :tolerable_max}
  end

  def tolerable_range_config(component)
    base_form_config
      .merge(TOLERANCE_RANGES[component.to_sym])
      .merge(colors: {below_range: slider_color(:excellent),
                      within_range: slider_color(:acceptable),
                      above_range: slider_color(:mediocre)})
  end

  def reldex_form_params
    base_form_config.merge({allowed_range: 0..1,
                             step: "0.05",
                             colors: {below_range: slider_color(:mediocre),
                                      within_range: slider_color(:acceptable),
                                      above_range: slider_color(:excellent)}})
  end

  def error_message_classes
    ["text-red-600", "dark:text-red-400"]
  end
end

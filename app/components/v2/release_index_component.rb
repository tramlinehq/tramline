class V2::ReleaseIndexComponent < V2::BaseComponent
  def initialize(release_index)
    @release_index = release_index
  end

  attr_reader :release_index

  def components
    release_index.components.order(weight: :desc)
  end

  TOLERANCE_RANGES = {
    hotfixes: {allowed_range: 0..5, step: 1},
    rollout_fixes: {allowed_range: 0..10, step: 1},
    rollout_duration: {allowed_range: 0..30, step: 1},
    duration: {allowed_range: 0..30, step: 1},
    stability_duration: {allowed_range: 0..20, step: 1},
    stability_changes: {allowed_range: 0..50, step: 1}
  }

  COLORS = {
    dark: {
      excellent: "#14532d",
      acceptable: "#0c4a6e",
      mediocre: "#881337"
    },
    light: {
      excellent: "#bbf7d0",
      acceptable: "#bae6fd",
      mediocre: "#fecdd3"
    }
  }
  def base_form_config
    {from_method: :tolerable_min,
     to_method: :tolerable_max}
  end

  def tolerable_range_config(component)
    base_form_config
      .merge(TOLERANCE_RANGES[component.to_sym])
      .merge(colors: {below_range: color(:excellent), within_range: color(:acceptable), above_range: color(:mediocre)})
  end

  def reldex_form_params
    base_form_config.merge({allowed_range: 0..1,
                             step: "0.1",
                             colors: {below_range: color(:mediocre), within_range: color(:acceptable), above_range: color(:excellent)}})
  end

  def bg_color(grade)
    case grade
    when :excellent
      "bg-green-100 dark:bg-green-900"
    when :acceptable
      "bg-sky-100 dark:bg-sky-900"
    when :mediocre
      "bg-rose-100 dark:bg-rose-900"
    else
      raise ArgumentError, "Invalid grade"
    end
  end

  private

  def color(grade, theme = :light)
    COLORS[theme][grade]
  end
end

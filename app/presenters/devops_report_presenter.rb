class DevopsReportPresenter < SimpleDelegator
  FORMATTING_DATA = {
    duration: {
      type: "area",
      value_format: "time",
      name: "devops.duration"
    },
    frequency: {
      type: "area",
      value_format: "number",
      name: "devops.frequency"
    },
    time_in_review: {
      type: "area",
      value_format: "time",
      name: "devops.time_in_review"
    },
    patch_fixes: {
      type: "area",
      value_format: "number",
      name: "devops.patch_fixes"
    },
    hotfixes: {
      type: "area",
      value_format: "number",
      name: "devops.hotfixes"
    },
    time_in_phases: {
      stacked: true,
      type: "stacked-bar",
      value_format: "time",
      name: "devops.time_in_phases",
      height: "250"
    },
    reldex_scores: {
      type: "line",
      value_format: "number",
      name: "devops.reldex",
      height: "250",
      show_y_axis: true
    },
    stability_contributors: {
      type: "line",
      value_format: "number",
      name: "operational_efficiency.stability_contributors",
      show_y_axis: true
    },
    contributors: {
      type: "line",
      value_format: "number",
      name: "operational_efficiency.contributors",
      show_y_axis: true
    },
    team_stability_contributors: {
      stacked: true,
      type: "stacked-bar",
      value_format: "number",
      name: "operational_efficiency.team_stability_contributors",
      show_y_axis: true,
      height: "250"
    },
    team_contributors: {
      stacked: true,
      type: "stacked-bar",
      value_format: "number",
      name: "operational_efficiency.team_contributors",
      show_y_axis: true,
      height: "250"
    }
  }

  def duration
    formatter(:duration)
  end

  def frequency
    formatter(:frequency)
  end

  def time_in_review
    formatter(:time_in_review)
  end

  def patch_fixes
    formatter(:patch_fixes)
  end

  def hotfixes
    formatter(:hotfixes)
  end

  def time_in_phases
    chart_data = formatter(:time_in_phases)
    # The data is in the following format:
    # {
    # "1.2.0"=>
    #     {"android"=>{:stability_time=>676092, :submission_time=>3535, :rollout_time=>591746},
    #      "ios"=>{:stability_time=>679607, :submission_time=>48894, :rollout_time=>565931}},
    # "1.3.0"=>
    #     {"android"=>{:stability_time=>508605, :submission_time=>5646, :rollout_time=>607813},
    #      "ios"=>{:stability_time=>517345, :submission_time=>129136, :rollout_time=>549477}}
    # }
    chart_data[:data] = chart_data[:data].transform_values do |release_data|
      release_data.transform_values { |platform_data| platform_data.transform_keys { |phase_name| phase_name.to_s.humanize } }
    end
    chart_data
  end

  def reldex_scores
    formatter(:reldex_scores, {
      y_annotations: [
        {y: 0..train.release_index.tolerable_range.min, text: "Mediocre", color: "mediocre"},
        {y: train.release_index.tolerable_range.max, text: "Excellent", color: "excellent"}
      ]
    })
  end

  def stability_contributors
    formatter(:stability_contributors)
  end

  def contributors
    formatter(:contributors)
  end

  def team_stability_contributors
    formatter(:team_stability_contributors, {
      colors: team_colors
    })
  end

  def team_contributors
    formatter(:team_contributors, {
      colors: team_colors
    })
  end

  def team_colors
    @team_colors ||= organization.team_colors
  end

  def formatter(key, params = {})
    return if all.blank?
    FORMATTING_DATA[key].merge(data: all[key]).merge(params)
  end

  delegate :present?, to: :all
end

class BuildHealthComponent < ViewComponent::Base
  attr_reader :release_platform_run, :step
  delegate :current_user, to: :helpers

  def initialize(step:, release_platform_run:)
    @step = step
    @release_platform_run = release_platform_run
  end

  def step_runs
    @step_runs ||= release_platform_run.step_runs_for(step).not_failed
  end

  def chartable_metadata
    ["app_size"].concat release_platform_run
      .external_builds
      .last
      .normalized_metadata
      .filter(&:numerical?)
      .map(&:identifier)
  end

  def app_size_data
    return {} unless step_runs.any?(&:build_size)
    {
      identifier: "app_size",
      name: "App Size",
      description: "",
      type: "number",
      unit: "MB",
      data: step_runs.map { |srun| [srun.build_number, {value: srun.build_size}] }.to_h
    }
  end

  def health_data
    return unless step_runs.size > 1

    @health_data ||= step_runs.each_with_object({"app_size" => app_size_data}) do |step_run, acc|
      metadata = step_run.external_build&.normalized_metadata
      next unless metadata

      metadata.each do |data|
        next unless data.numerical?

        acc[data.identifier] ||= {
          identifier: data.identifier,
          name: data.name,
          description: data.description,
          type: data.type,
          unit: data.unit,
          data: {}
        }

        acc[data.identifier][:data][step_run.build_number] = {data.unit => data.value}
      end
    end
  end

  def chart_data(metadata_id)
    {
      data: health_data[metadata_id][:data],
      type: "line",
      value_format: health_data[metadata_id][:type],
      name: metadata_id,
      title: health_data[metadata_id][:name],
      scope: "All builds",
      help_text: "",
      show_x_axis: false,
      show_y_axis: true
    }
  end
end

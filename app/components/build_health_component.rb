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
    ["app_size"].concat release_platform_run.external_builds.last.metadata.filter { |_k, v| v["type"] == "number" }.keys
  end

  def app_size_data
    {"app_size" => {
      identifier: "app_size",
      name: "App Size",
      description: "",
      type: "number",
      unit: "MB",
      data: step_runs.map { |srun| [srun.build_number, {value: srun.build_size}] }.to_h
    }}
  end

  def health_data
    return unless step_runs.size > 1

    step_runs.each_with_object(app_size_data) do |step_run, acc|
      metadata = step_run.external_build&.metadata
      next unless metadata

      metadata.each do |identifier, data|
        next unless data["type"] == "number"

        acc[identifier] ||= {
          identifier: data["identifier"],
          name: data["name"],
          description: data["description"],
          type: data["type"],
          unit: data["unit"],
          data: {}
        }

        acc[identifier][:data][step_run.build_number] = {value: data["value"]}
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
      scope: "Last 5 builds",
      help_text: ""
    }
  end
end

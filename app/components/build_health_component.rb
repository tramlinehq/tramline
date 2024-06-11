class BuildHealthComponent < ViewComponent::Base
  attr_reader :release_platform_run, :step, :show_title
  delegate :current_user, to: :helpers

  def initialize(step:, release_platform_run:, show_title: true)
    @step = step
    @release_platform_run = release_platform_run
    @show_title = show_title
  end

  def step_runs
    @step_runs ||= release_platform_run.step_runs_for(step).not_failed.sequential
  end

  def chartable_metadata
    default_metadata = ["app_size"]
    external_metadata = release_platform_run
      .external_builds
      .last
      .normalized_metadata
      .filter(&:numerical?)
      .map(&:identifier)
    (default_metadata + external_metadata).uniq
  end

  def app_size_data
    return nil unless step_runs.any?(&:build_size)

    {
      identifier: "app_size",
      name: "App Size",
      description: "",
      type: "number",
      unit: "MB",
      data: step_runs.map { |srun| [srun.build_number, {"MB" => srun.build_size}] if srun.build_size }.compact.to_h
    }
  end

  def health_data
    return unless step_runs.size > 1

    initial_health_data = app_size_data
    if release_platform_run.external_builds.any? { |em| em.normalized_metadata.any? { |m| m.identifier == "app_size" } }
      initial_health_data = {}
    end

    @health_data ||= step_runs.each_with_object(initial_health_data) do |step_run, acc|
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

  def chartable?(metadata_id)
    health_data[metadata_id].present?
  end

  def chart_data(metadata_id)
    return if health_data[metadata_id].blank?
    {
      data: health_data[metadata_id][:data].sort.to_h,
      type: "line",
      value_format: health_data[metadata_id][:type],
      name: metadata_id,
      title: health_data[metadata_id][:name],
      scope: "Across all the builds",
      help_text: health_data[metadata_id][:description],
      show_x_axis: false,
      show_y_axis: true
    }
  end
end

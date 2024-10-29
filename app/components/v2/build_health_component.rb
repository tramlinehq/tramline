# frozen_string_literal: true

class V2::BuildHealthComponent < ViewComponent::Base
  def initialize(release_platform_run:, builds:)
    @release_platform_run = release_platform_run
    @builds = builds
  end

  def external_builds
    @external_builds ||= @builds.flat_map(&:external_build).compact
  end

  def chartable_metadata
    default_metadata = ["app_size"]
    external_metadata = []
    if external_builds.present?
      external_metadata = external_builds
        .last
        .normalized_metadata
        .filter(&:numerical?)
        .map(&:identifier)
    end
    (default_metadata + external_metadata).uniq
  end

  def health_data
    return if @builds.size <= 1

    @health_data ||= @builds.each_with_object({}) do |build, acc|
      acc["app_size"] ||= {
        identifier: "app_size",
        name: "App Size",
        description: "This is the size of the build file in MB",
        type: "number",
        unit: "MB",
        data: {}
      }
      acc["app_size"][:data][build.build_number] = {"MB" => build.size_in_mb} if build.size_in_mb.present?
      metadata = build.external_build&.normalized_metadata
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

        acc[data.identifier][:data][build.build_number] = {data.unit => data.value}
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

class BuildMetadataComponent < ViewComponent::Base
  attr_reader :step_run

  UNIT_MAPPING = {
    "seconds" => "secs",
    "milliseconds" => "ms",
    "percentage" => "%"
  }

  def initialize(step_run:)
    @step_run = step_run
  end

  def external_build
    @external_build ||= step_run.external_build
  end

  def metrics
    values = {"App Size" => {value: step_run.build_size, unit: "MB"}}
    values.merge number_values.to_h { |metadata|
      [metadata.name, {value: metadata.value, unit: UNIT_MAPPING.fetch(metadata.unit, metadata.unit)}]
    }
  end

  def number_values
    return [] unless external_build
    external_build.normalized_metadata.filter(&:numerical?)
  end

  def text_values
    return [] unless external_build
    external_build.normalized_metadata.filter(&:textual?)
  end
end

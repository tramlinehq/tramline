class BuildMetadataComponent < ViewComponent::Base
  attr_reader :step_run

  UNIT_MAPPING = {
    "seconds" => "secs",
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
    values.merge number_values.to_h { |_k, metadata|
      [metadata["name"], {value: metadata["value"], unit: UNIT_MAPPING.fetch(metadata["unit"], nil)}]
    }
  end

  def number_values
    external_build.metadata.filter { |_k, metadata| metadata["type"] == "number" }
  end

  def text_values
    external_build.metadata.filter { |_k, metadata| metadata["type"] == "text" }
  end
end

class BuildHealthComponent < ViewComponent::Base
  attr_reader :release_platform_run, :step
  delegate :current_user, to: :helpers

  def initialize(step:, release_platform_run:)
    @step = step
    @release_platform_run = release_platform_run
  end

  def latest_step_run
    release_platform_run.last_run_for(step)
  end

  def health_data
    {
      app_launch_time: {
        identifier: "app_launch_time",
        name: "App Launch Time",
        description: "This is the time in seconds for the app to start",
        type: "number",
        unit: "seconds",
        data: { "123": { value: 1.5 }, "124": { value: 1.0 }, "125": { value: 1.2 }, "126": { value: 1.1 } } },
      unit_test_coverage: {
        identifier: "unit_test_coverage",
        name: "Unit Test Coverage",
        description: "This is the time in seconds for the app to start",
        type: "number",
        unit: "seconds",
        data: { "123": { value: 50 }, "124": { value: 55 }, "125": { value: 50 }, "126": { value: 45 } }
      },
      mint_coverage: {
        identifier: "mint_coverage",
        name: "Mint Coverage",
        description: "This is the time in seconds for the app to start",
        type: "number",
        unit: "seconds",
        data: { "123": { value: 90 }, "124": { value: 85 }, "125": { value: 80 }, "126": { value: 85 } }
      }
    }
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

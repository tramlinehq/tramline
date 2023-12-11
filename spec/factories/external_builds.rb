FactoryBot.define do
  factory :external_build do
    association :step_run
    metadata {
      {
        "app_launch_time" => {
          identifier: "app_launch_time",
          name: "App Launch Time",
          description: "This is the time in seconds for the app to start",
          value: "0.5",
          type: "number",
          unit: "seconds"
        },
        "unit_test_coverage" => {
          identifier: "unit_test_coverage",
          name: "Unit Test Coverage",
          description: "Percentage of code covered by unit tests",
          value: "60",
          type: "number",
          unit: "percentage"
        },
        "mint_coverage" => {
          identifier: "mint_coverage",
          name: "Mint Coverage",
          description: "Something about mint coverage",
          value: "40",
          type: "number",
          unit: "percentage"
        },
        "end_to_end_test_report" => {
          identifier: "end_to_end_test_report",
          name: "End to end test report",
          description: "A long report about end-to-end tests run against the build",
          value: "It is a long-established fact that a reader will be distracted.",
          type: "string",
          unit: "none"
        }
      }
    }
  end
end

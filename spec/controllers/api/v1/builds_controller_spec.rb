require "rails_helper"

describe Api::V1::BuildsController do
  let(:organization) { create(:organization) }
  let(:app) { create(:app, :cross_platform, organization:) }
  let(:train) { create(:train, app:) }
  let(:release) { create(:release, train:) }
  let(:step_run) { create(:step_run, release_platform_run: release.release_platform_runs.first) }
  let(:metadata_params) {
    [
      {
        identifier: "app_launch_time",
        name: "App Launch Time",
        description: "This is the time in seconds for the app to start",
        value: "0.5",
        type: "number",
        unit: "seconds"
      },
      {
        identifier: "unit_test_coverage",
        name: "Unit Test Coverage",
        description: "Percentage of code covered by unit tests",
        value: "60",
        type: "number",
        unit: "percentage"
      },
      {
        identifier: "mint_coverage",
        name: "Mint Coverage",
        description: "Something about mint coverage",
        value: "40",
        type: "number",
        unit: "percentage"
      },
      {
        identifier: "end_to_end_test_report",
        name: "End to end test report",
        description: "A long report about end-to-end tests run against the build",
        value: "It is a long-established fact that a reader will be distracted.",
        type: "text",
        unit: "none"
      }
    ]
  }

  before do
    request.headers["HTTP_X_TRAMLINE_ACCOUNT_ID"] = organization.id
    request.headers["Authorization"] = "Bearer #{organization.api_key}"
  end

  it "creates the external build metadata for the step run" do
    patch :external_metadata,
      format: :json,
      params: {app_id: app.slug, version_name: step_run.build_version, version_code: step_run.build_number, external_metadata: metadata_params}
    expect(response).to have_http_status(:success)
    expect(response.parsed_body["external_build_metadata"]["metadata"].values).to match_array(metadata_params.map(&:with_indifferent_access))
  end

  it "updates the external build metadata for the step run" do
    single_metadata = [
      {
        identifier: "app_launch_time",
        name: "App Launch Time",
        description: "This is the time in seconds for the app to start",
        value: "1.5",
        type: "number",
        unit: "seconds"
      }
    ]
    old_metadata = create(:external_build_metadata, step_run:)
    patch :external_metadata,
      format: :json,
      params: {app_id: app.slug, version_name: step_run.build_version, version_code: step_run.build_number, external_metadata: single_metadata}
    expect(response).to have_http_status(:success)
    new_metadata = response.parsed_body["external_build_metadata"]
    expect(new_metadata.dig("metadata", "app_launch_time")).to eq(single_metadata.find { |m| m[:identifier] == "app_launch_time" }.with_indifferent_access)
    expect(new_metadata.dig("metadata", "unit_test_coverage")).to eq(old_metadata.metadata.fetch("unit_test_coverage"))
  end
end

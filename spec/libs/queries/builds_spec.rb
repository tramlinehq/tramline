require "rails_helper"

describe Queries::Builds, type: :model do
  describe "#call" do
    let(:limit) { 10 }
    let(:offset) { 0 }
    let(:sort_column) { "version_code" }
    let(:sort_direction) { "asc" }
    let(:params) { Queries::Helpers::Parameters.new }

    it "returns an Queries::Build object" do
      app = create(:app, :android)
      train = create(:train, app:)
      release_platform = create(:release_platform, app:, train:)
      step = create(:step, :with_deployment, release_platform:)
      step_run = create(:step_run, step:)
      create(:build_artifact, step_run:)

      actual = described_class.all(app:, params:).first
      expect(actual).to be_a(Queries::Build)
    end

    it "return the correct number of builds" do
      app = create(:app, :android)
      train = create(:train, app:)
      release_platform = create(:release_platform, app:, train:)
      step = create(:step, :with_deployment, release_platform:)
      step_run1 = create(:step_run, step:)
      step_run2 = create(:step_run, step:)
      create(:build_artifact, step_run: step_run1)
      create(:build_artifact, step_run: step_run2)

      actual = described_class.all(app:, params:).size
      expect(actual).to eq(2)
    end

    it "returns all the fields" do
      app = create(:app, :android)
      train = create(:train, app:)
      release_platform = create(:release_platform, app:, train:)
      step = create(:step, :with_deployment, release_platform:)
      step_run = create(:step_run, step:)
      create(:build_artifact, step_run:)

      expected_keys = [
        "version_name",
        "version_code",
        "built_at",
        "release_status",
        "step_status",
        "train_name",
        "platform",
        "step_name",
        "ci_link",
        "deployments",
        "download_url",
        "external_release_status"
      ]

      actual = described_class.all(app:, params:).first.attributes.keys
      expect(actual).to match_array(expected_keys)
    end
  end
end

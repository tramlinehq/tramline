require "rails_helper"

describe Queries::Builds, type: :model do
  describe "#call" do
    let(:limit) { 10 }
    let(:offset) { 0 }
    let(:sort_column) { "version_code" }
    let(:sort_direction) { "asc" }

    it "returns an Queries::Build object" do
      app = create(:app, :android)
      train = create(:releases_train, app:)
      step = create(:releases_step, :with_deployment, train:)
      step_run = create(:releases_step_run, step:)
      create(:build_artifact, step_run:)

      actual = described_class.all(app:, limit:, offset:, sort_column:, sort_direction:).first
      expect(actual).to be_a(described_class)
    end

    it "return the correct number of builds" do
      app = create(:app, :android)
      train = create(:releases_train, app:)
      step = create(:releases_step, :with_deployment, train:)
      step_run1 = create(:releases_step_run, step:)
      step_run2 = create(:releases_step_run, step:)
      create(:build_artifact, step_run: step_run1)
      create(:build_artifact, step_run: step_run2)

      actual = described_class.all(app:, limit:, offset:, sort_column:, sort_direction:).size
      expect(actual).to eq(2)
    end

    it "returns all the fields" do
      app = create(:app, :android)
      train = create(:releases_train, app:)
      step = create(:releases_step, :with_deployment, train:)
      step_run = create(:releases_step_run, step:)
      create(:build_artifact, step_run:)

      expected_keys = [
        "version_name",
        "version_code",
        "built_at",
        "release_status",
        "step_status",
        "train_name",
        "step_name",
        "ci_link",
        "deployments",
        "download_url",
        "external_release_status"
      ]

      actual = described_class.all(app:, limit:, offset:, sort_column:, sort_direction:).first.attributes.keys
      expect(actual).to contain_exactly(*expected_keys)
    end
  end
end

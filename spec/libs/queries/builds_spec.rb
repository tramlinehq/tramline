require "rails_helper"

describe Queries::Builds, type: :model do
  describe "#call" do
    let(:limit) { 10 }
    let(:offset) { 0 }
    let(:sort_column) { "version_code" }
    let(:sort_direction) { "asc" }
    let(:params) do
      params = Queries::Helpers::Parameters.new
      params.add_search_query("test")
      params
    end

    it "returns an Queries::Build object" do
      app = create(:app, :android)
      train = create(:train, app:)
      release_platform = create(:release_platform, app:, train:)
      release_platform_run = create(:release_platform_run, :on_track, release_platform:)
      _build = create(:build, release_platform_run:, version_name: "test-build")

      actual = described_class.all(app:, params:).first
      expect(actual).to be_a(Queries::Build)
    end

    it "return the correct number of builds" do
      app = create(:app, :android)
      train = create(:train, app:)
      release_platform = create(:release_platform, app:, train:)
      release_platform_run = create(:release_platform_run, :on_track, release_platform:)
      _build_1 = create(:build, release_platform_run:, version_name: "test-build-1")
      _build_2 = create(:build, release_platform_run:, version_name: "test-build-2")

      actual = described_class.all(app:, params:).size
      expect(actual).to eq(2)
    end

    it "returns all the fields" do
      app = create(:app, :android)
      train = create(:train, app:)
      release_platform = create(:release_platform, app:, train:)
      release_platform_run = create(:release_platform_run, :on_track, release_platform:)
      _build = create(:build, release_platform_run:, version_name: "test-build")

      expected_keys = %w[version_name version_code built_at release_status train_name platform kind ci_link submissions download_url]

      actual = described_class.all(app:, params:).first.attributes.keys
      expect(actual).to match_array(expected_keys)
    end
  end
end

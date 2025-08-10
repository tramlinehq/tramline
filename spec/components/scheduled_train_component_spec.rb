require "rails_helper"

RSpec.describe ScheduledTrainComponent, type: :component do
  let(:app) { create(:app, :android) }

  describe "#next_next_version" do
    context "when using SemVer strategy" do
      context "when there is no ongoing release" do
        let(:train) { create(:train, app:, version_seeded_with: "1.2.3", versioning_strategy: :semver) }
        let(:component) { described_class.new(train) }

        it "returns the train's next-to-next version" do
          expect(component.next_next_version).to eq("1.4.0")
        end
      end

      context "when there is an ongoing release" do
        let(:train) { create(:train, app:, version_seeded_with: "1.2.3", versioning_strategy: :semver) }
        let!(:ongoing_release) { create(:release, :on_track, train:, original_release_version: "1.3.0") }
        let(:component) { described_class.new(train) }

        it "returns the ongoing release's next-to-next version" do
          expect(component.next_next_version).to eq("1.5.0")
        end
      end
    end

    context "when using CalVer strategy" do
      before do
        travel_to(Time.new(2025, 5, 23, 12, 0, 0, "+00:00"))
      end

      after do
        travel_back
      end

      context "when there is no ongoing release" do
        let(:train) { create(:train, app:, version_seeded_with: "2025.05.22", versioning_strategy: :calver) }
        let(:component) { described_class.new(train) }

        it "returns the train's future version (next day) using future_version" do
          expect(component.next_version).to eq("2025.05.23")  # Current date
          expect(component.next_next_version).to eq("2025.05.24")  # Next day
        end
      end

      context "when there is an ongoing release" do
        let(:train) { create(:train, app:, version_seeded_with: "2025.05.22", versioning_strategy: :calver) }
        let!(:ongoing_release) { create(:release, :on_track, train: train, original_release_version: "2025.05.23") }
        let(:component) { described_class.new(train) }

        it "returns the ongoing release's future version (next day) using future_version" do
          expect(component.next_version).to eq("2025.05.23")  # Current date
          expect(component.next_next_version).to eq("2025.05.24")  # Next day
        end
      end
    end
  end
end

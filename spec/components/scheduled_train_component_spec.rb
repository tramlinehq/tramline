require "rails_helper"

RSpec.describe ScheduledTrainComponent, type: :component do
  let(:app) { create(:app, :android) }

  describe "#next_next_version" do
    context "when using SemVer strategy" do
      let(:train) { create(:train, app:, version_seeded_with: "1.2.3", versioning_strategy: :semver) }
      let(:component) { described_class.new(train) }

      context "when there is no ongoing release" do
        it "returns the train's next-to-next version" do
          expect(component.next_next_version).to eq("1.4.0")
        end
      end

      context "when there is an ongoing release" do
        before do
          create(:release, :on_track, train:, original_release_version: "1.3.0")
        end

        it "returns the ongoing release's next-to-next version" do
          expect(component.next_next_version).to eq("1.5.0")
        end
      end
    end

    context "when using CalVer strategy" do
      context "when there is no ongoing release" do
        [
          [Time.new(2025, 5, 23, 22, 0, 0, "+00:00"), 1.day, "2025.05.24"],
          [Time.new(2025, 5, 31, 0, 0, 0, "+00:00"), 1.day, "2025.06.01"],
          [Time.new(2025, 12, 31, 0, 0, 0, "+00:00"), 1.day, "2026.01.01"],
          [Time.new(2025, 5, 23, 22, 0, 0, "+00:00"), 2.days, "2025.05.25"],
          [Time.new(2025, 5, 23, 22, 0, 0, "+00:00"), 1.week, "2025.05.30"]
        ].each do |test_time, repeat_duration, expected_result|
          it "returns the train's next-to-next version scheduled #{repeat_duration.inspect} after #{test_time.strftime("%Y.%d.%m")}" do
            train = create(:train, :with_schedule,
              app:,
              version_seeded_with: "2025.01.01",
              versioning_strategy: :calver,
              repeat_duration: repeat_duration)
            component = described_class.new train
            travel_to(test_time) do
              expect(component.next_next_version).to eq(expected_result)
            end
          end
        end
      end

      context "when there is an ongoing release" do
        [
          [Time.new(2025, 5, 23, 22, 0, 0, "+00:00"), 1.day, "2025.05.24"],
          [Time.new(2025, 5, 31, 0, 0, 0, "+00:00"), 1.day, "2025.06.01"],
          [Time.new(2025, 12, 31, 0, 0, 0, "+00:00"), 1.day, "2026.01.01"],
          [Time.new(2025, 5, 23, 22, 0, 0, "+00:00"), 2.days, "2025.05.25"],
          [Time.new(2025, 5, 23, 22, 0, 0, "+00:00"), 1.week, "2025.05.30"]
        ].each do |test_time, repeat_duration, expected_result|
          it "returns the release's next-to-next version scheduled #{repeat_duration.inspect} after #{test_time.strftime("%Y.%d.%m")}" do
            train = create(:train, :with_schedule,
              app:,
              version_seeded_with: "2025.01.01",
              versioning_strategy: :calver,
              repeat_duration: repeat_duration)
            create(:release, :on_track, train: train, original_release_version: "2025.01.31")
            component = described_class.new train
            travel_to(test_time) do
              expect(component.next_next_version).to eq(expected_result)
            end
          end
        end
      end
    end
  end
end

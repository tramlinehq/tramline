require "rails_helper"

describe ScheduledTrainComponent, type: :component do
  let(:app) { create(:app, :android) }

  describe "#next_version" do
    context "when using SemVer strategy" do
      let(:train) { create(:train, app:, version_seeded_with: "1.2.3", versioning_strategy: :semver) }
      let(:component) { described_class.new(train) }

      context "when there is no ongoing release" do
        it "returns the train's next version" do
          expect(component.next_version).to eq("1.3.0")
        end
      end

      context "when there is an ongoing release" do
        before do
          create(:release, :on_track, train:, original_release_version: "1.3.0")
        end

        it "returns the ongoing release's next version" do
          expect(component.next_version).to eq("1.4.0")
        end
      end
    end

    context "when using CalVer strategy" do
      context "when there is no ongoing release" do
        [
          [Time.new(2025, 8, 18, 8, 0, 0, "+00:00"), Time.new(2025, 8, 19, 9, 0, 0, "+00:00"), "2025.08.19"],
          [Time.new(2025, 8, 31, 21, 0, 0, "+00:00"), Time.new(2025, 9, 1, 22, 0, 0, "+00:00"), "2025.09.01"],
          [Time.new(2025, 12, 31, 12, 0, 0, "+00:00"), Time.new(2026, 1, 1, 13, 0, 0, "+00:00"), "2026.01.01"]
        ].each do |creation_time, scheduled_time, expected_version|
          it "returns the train's next version with releases scheduled every day" do
            train = nil

            travel_to creation_time do
              train = create(:train, :with_schedule,
                app:,
                version_seeded_with: "2025.01.01",
                versioning_strategy: :calver,
                repeat_duration: 1.day,
                kickoff_at: creation_time + 1.hour)

              create(:scheduled_release, train:, scheduled_at: scheduled_time)
            end

            travel_to creation_time + 30.minutes do
              component = described_class.new train
              expect(component.next_version).to eq(expected_version)
            end
          end
        end

        [
          [Time.new(2025, 8, 18, 8, 0, 0, "+00:00"), Time.new(2025, 8, 20, 9, 0, 0, "+00:00"), 2.days, "2025.08.20", "every 2 days"],
          [Time.new(2025, 8, 18, 8, 0, 0, "+00:00"), Time.new(2025, 8, 25, 9, 0, 0, "+00:00"), 1.week, "2025.08.25", "every week"]
        ].each do |creation_time, scheduled_time, repeat_duration, expected_version, schedule_description|
          it "returns the train's next version with releases scheduled #{schedule_description}" do
            train = nil

            travel_to creation_time do
              train = create(:train, :with_schedule,
                app:,
                version_seeded_with: "2025.01.01",
                versioning_strategy: :calver,
                repeat_duration:,
                kickoff_at: creation_time + 1.hour)
              create(:scheduled_release, train:, scheduled_at: scheduled_time)
            end

            travel_to creation_time + 1.day do
              component = described_class.new train
              expect(component.next_version).to eq(expected_version)
            end
          end
        end
      end

      context "when there is an ongoing release" do
        [
          [Time.new(2025, 8, 18, 8, 0, 0, "+00:00"), Time.new(2025, 8, 19, 9, 0, 0, "+00:00"), "2025.08.19"],
          [Time.new(2025, 8, 31, 21, 0, 0, "+00:00"), Time.new(2025, 9, 1, 22, 0, 0, "+00:00"), "2025.09.01"],
          [Time.new(2025, 12, 31, 12, 0, 0, "+00:00"), Time.new(2026, 1, 1, 13, 0, 0, "+00:00"), "2026.01.01"]
        ].each do |creation_time, scheduled_time, expected_version|
          it "returns the ongoing release's next version with releases scheduled every day" do
            train = nil

            travel_to creation_time do
              train = create(:train, :with_schedule,
                app:,
                version_seeded_with: "2025.01.01",
                versioning_strategy: :calver,
                repeat_duration: 1.day,
                kickoff_at: creation_time + 1.hour)
              scheduled_release = create(:scheduled_release, train:, scheduled_at: scheduled_time)
              create(:release, :on_track, train:, original_release_version: "2025.02.01", scheduled_release:)
            end

            travel_to creation_time + 30.minutes do
              component = described_class.new train
              expect(component.next_version).to eq(expected_version)
            end
          end
        end

        [
          [Time.new(2025, 8, 18, 8, 0, 0, "+00:00"), Time.new(2025, 8, 20, 9, 0, 0, "+00:00"), 2.days, "2025.08.20", "every 2 days"],
          [Time.new(2025, 8, 18, 8, 0, 0, "+00:00"), Time.new(2025, 8, 25, 9, 0, 0, "+00:00"), 1.week, "2025.08.25", "every week"]
        ].each do |creation_time, scheduled_time, repeat_duration, expected_version, schedule_description|
          it "returns the ongoing release's next version with releases scheduled #{schedule_description}" do
            train = nil

            travel_to creation_time do
              train = create(:train, :with_schedule,
                app:,
                version_seeded_with: "2025.01.01",
                versioning_strategy: :calver,
                repeat_duration:,
                kickoff_at: creation_time + 1.hour)
              scheduled_release = create(:scheduled_release, train:, scheduled_at: scheduled_time)
              create(:release, :on_track, train:, original_release_version: "2025.02.01", scheduled_release:)
            end

            travel_to creation_time + 1.day do
              component = described_class.new train
              expect(component.next_version).to eq(expected_version)
            end
          end
        end
      end
    end
  end

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
          [Time.new(2025, 8, 18, 8, 0, 0, "+00:00"), Time.new(2025, 8, 19, 9, 0, 0, "+00:00"), "2025.08.20"],
          [Time.new(2025, 8, 31, 21, 0, 0, "+00:00"), Time.new(2025, 9, 1, 22, 0, 0, "+00:00"), "2025.09.02"],
          [Time.new(2025, 12, 31, 12, 0, 0, "+00:00"), Time.new(2026, 1, 1, 13, 0, 0, "+00:00"), "2026.01.02"]
        ].each do |creation_time, scheduled_time, expected_version|
          it "returns the train's next-next version with releases scheduled every day" do
            train = nil

            travel_to creation_time do
              train = create(:train, :with_schedule,
                app:,
                version_seeded_with: "2025.01.01",
                versioning_strategy: :calver,
                repeat_duration: 1.day,
                kickoff_at: creation_time + 1.hour)

              create(:scheduled_release, train:, scheduled_at: scheduled_time)
            end

            travel_to creation_time + 30.minutes do
              component = described_class.new train
              expect(component.next_next_version).to eq(expected_version)
            end
          end
        end

        [
          [Time.new(2025, 8, 18, 8, 0, 0, "+00:00"), Time.new(2025, 8, 20, 9, 0, 0, "+00:00"), 2.days, "2025.08.22", "every 2 days"],
          [Time.new(2025, 8, 18, 8, 0, 0, "+00:00"), Time.new(2025, 8, 25, 9, 0, 0, "+00:00"), 1.week, "2025.09.01", "every week"]
        ].each do |creation_time, scheduled_time, repeat_duration, expected_version, schedule_description|
          it "returns the train's next-next version with releases scheduled #{schedule_description}" do
            train = nil

            travel_to creation_time do
              train = create(:train, :with_schedule,
                app:,
                version_seeded_with: "2025.01.01",
                versioning_strategy: :calver,
                repeat_duration:,
                kickoff_at: creation_time + 1.hour)
              create(:scheduled_release, train:, scheduled_at: scheduled_time)
            end

            travel_to creation_time + 1.day do
              component = described_class.new train
              expect(component.next_next_version).to eq(expected_version)
            end
          end
        end
      end

      context "when there is an ongoing release" do
        [
          [Time.new(2025, 8, 18, 8, 0, 0, "+00:00"), Time.new(2025, 8, 20, 9, 0, 0, "+00:00"), "2025.08.21"],
          [Time.new(2025, 8, 31, 21, 0, 0, "+00:00"), Time.new(2025, 9, 1, 22, 0, 0, "+00:00"), "2025.09.02"],
          [Time.new(2025, 12, 31, 12, 0, 0, "+00:00"), Time.new(2026, 1, 1, 13, 0, 0, "+00:00"), "2026.01.02"]
        ].each do |creation_time, scheduled_time, expected_version|
          it "returns the ongoing release's next-next version with releases scheduled every day" do
            train = nil

            travel_to creation_time do
              train = create(:train, :with_schedule,
                app:,
                version_seeded_with: "2025.01.01",
                versioning_strategy: :calver,
                repeat_duration: 1.day,
                kickoff_at: creation_time + 1.hour)
              scheduled_release = create(:scheduled_release, train:, scheduled_at: scheduled_time)
              create(:release, :on_track, train:, original_release_version: "2025.02.01", scheduled_release:)
            end

            travel_to creation_time + 30.minutes do
              component = described_class.new train
              expect(component.next_next_version).to eq(expected_version)
            end
          end
        end

        [
          [Time.new(2025, 8, 18, 8, 0, 0, "+00:00"), Time.new(2025, 8, 20, 9, 0, 0, "+00:00"), 2.days, "2025.08.22", "every 2 days"],
          [Time.new(2025, 8, 18, 8, 0, 0, "+00:00"), Time.new(2025, 8, 25, 9, 0, 0, "+00:00"), 1.week, "2025.09.01", "every week"]
        ].each do |creation_time, scheduled_time, repeat_duration, expected_version, schedule_description|
          it "returns the ongoing release's next-next version with releases scheduled #{schedule_description}" do
            train = nil

            travel_to creation_time do
              train = create(:train, :with_schedule,
                app:,
                version_seeded_with: "2025.01.01",
                versioning_strategy: :calver,
                repeat_duration:,
                kickoff_at: creation_time + 1.hour)
              scheduled_release = create(:scheduled_release, train:, scheduled_at: scheduled_time)
              create(:release, :on_track, train:, original_release_version: "2025.02.01", scheduled_release:)
            end

            travel_to creation_time + 1.day do
              component = described_class.new train
              expect(component.next_next_version).to eq(expected_version)
            end
          end
        end
      end
    end
  end
end

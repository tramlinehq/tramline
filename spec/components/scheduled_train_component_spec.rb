require "rails_helper"

RSpec.describe ScheduledTrainComponent, type: :component do
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

    context "when using CalVer strategy with no ongoing release and daily schedules" do
      [
        # [creation_time, kickoff_time, scheduled_time, expected_version, description]
        [
          Time.new(2025, 8, 18, 8, 0, 0, "+00:00"),   # creation time
          Time.new(2025, 8, 18, 9, 0, 0, "+00:00"),   # kickoff time (future relative to creation)
          Time.new(2025, 8, 19, 9, 0, 0, "+00:00"),   # scheduled release time (next day)
          "2025.08.19",                               # expected version based on scheduled time
          "daily schedule"
        ],
        [
          Time.new(2025, 8, 30, 10, 0, 0, "+00:00"),  # creation time
          Time.new(2025, 8, 30, 11, 0, 0, "+00:00"),  # kickoff time
          Time.new(2025, 9, 1, 11, 0, 0, "+00:00"),   # scheduled release time (month boundary)
          "2025.09.01",                               # expected version based on scheduled time
          "month boundary crossing"
        ],
        [
          Time.new(2025, 12, 30, 10, 0, 0, "+00:00"), # creation time
          Time.new(2025, 12, 30, 11, 0, 0, "+00:00"), # kickoff time
          Time.new(2025, 12, 31, 11, 0, 0, "+00:00"), # scheduled release time (year boundary)
          "2025.12.31",                               # expected version based on scheduled time
          "year boundary crossing"
        ]
      ].each do |creation_time, kickoff_time, scheduled_time, expected_version, description|
        it "returns CalVer based on scheduled time for #{description}" do
          train = nil

          # Create train when kickoff_at is in the future
          travel_to(creation_time) do
            train = create(:train, :with_schedule,
              app:,
              version_seeded_with: "2025.01.01",
              versioning_strategy: :calver,
              repeat_duration: 1.day,
              kickoff_at: creation_time + 1.hour)
            # Create scheduled release
            create(:scheduled_release, train:, scheduled_at: scheduled_time)
          end

          # Test partway to scheduled time (realistic for daily releases too)
          test_time = creation_time + (scheduled_time - creation_time) * 0.6
          travel_to(test_time) do
            component = described_class.new train
            expect(component.next_version).to eq(expected_version)
          end
        end
      end
    end

    context "when using CalVer strategy with no ongoing release and longer duration schedules" do
      [
        # [creation_time, kickoff_time, scheduled_time, repeat_duration, expected_version, description]
        [
          Time.new(2025, 8, 18, 8, 0, 0, "+00:00"),   # creation time
          Time.new(2025, 8, 18, 9, 0, 0, "+00:00"),   # kickoff time (future relative to creation)
          Time.new(2025, 8, 20, 9, 0, 0, "+00:00"),   # scheduled release time
          2.days,                                      # repeat duration
          "2025.08.20",                               # expected version based on scheduled time
          "every other day schedule"
        ],
        [
          Time.new(2025, 8, 18, 8, 0, 0, "+00:00"),   # creation time
          Time.new(2025, 8, 18, 9, 0, 0, "+00:00"),   # kickoff time
          Time.new(2025, 8, 25, 9, 0, 0, "+00:00"),   # scheduled release time (1 week later)
          1.week,                                      # repeat duration
          "2025.08.25",                               # expected version based on scheduled time
          "weekly schedule"
        ]
      ].each do |creation_time, kickoff_time, scheduled_time, repeat_duration, expected_version, description|
        it "returns CalVer based on scheduled time for #{description}" do
          train = nil

          # Create train when kickoff_at is in the future
          travel_to(creation_time) do
            train = create(:train, :with_schedule,
              app:,
              version_seeded_with: "2025.01.01",
              versioning_strategy: :calver,
              repeat_duration: repeat_duration,
              kickoff_at: creation_time + 1.hour)
            # Create scheduled release
            create(:scheduled_release, train:, scheduled_at: scheduled_time)
          end

          # Test partway to scheduled time (realistic for longer durations)
          test_time = creation_time + (scheduled_time - creation_time) * 0.7
          travel_to(test_time) do
            component = described_class.new train
            expect(component.next_version).to eq(expected_version)
          end
        end
      end
    end

    context "when using CalVer strategy with ongoing release and daily schedules" do
      [
        [Time.new(2025, 8, 22, 12, 0, 0, "+00:00"), Time.new(2025, 8, 23, 12, 0, 0, "+00:00"), Time.new(2025, 8, 24, 12, 0, 0, "+00:00"), "2025.08.24"],
        [Time.new(2025, 8, 30, 12, 0, 0, "+00:00"), Time.new(2025, 8, 31, 12, 0, 0, "+00:00"), Time.new(2025, 9, 1, 12, 0, 0, "+00:00"), "2025.09.01"],
        [Time.new(2025, 12, 30, 12, 0, 0, "+00:00"), Time.new(2025, 12, 31, 12, 0, 0, "+00:00"), Time.new(2026, 1, 1, 12, 0, 0, "+00:00"), "2026.01.01"]
      ].each do |last_run_at, ongoing_at, next_run_at, expected_result|
        it "returns CalVer based on next scheduled run (#{next_run_at.strftime("%Y.%m.%d")}) after ongoing release with daily duration" do
          train = nil
          component = nil

          # Create train when kickoff_at is in the future
          travel_to(last_run_at - 1.hour) do
            train = create(:train, :with_schedule,
              app:,
              version_seeded_with: "2025.01.01",
              versioning_strategy: :calver,
              repeat_duration: 1.day,
              kickoff_at: last_run_at)
            # Create ongoing release scheduled at ongoing_at
            ongoing_scheduled_release = create(:scheduled_release, train: train, scheduled_at: ongoing_at)
            create(:release, :on_track, train: train, scheduled_release: ongoing_scheduled_release)
            # Create next scheduled release
            create(:scheduled_release, train: train, scheduled_at: next_run_at)
          end

          # Test partway to next scheduled time (realistic for daily releases too)
          test_time = ongoing_at + (next_run_at - ongoing_at) * 0.6
          travel_to(test_time) do
            component = described_class.new train
            expect(component.next_version).to eq(expected_result)
          end
        end
      end
    end

    context "when using CalVer strategy with ongoing release and longer duration schedules" do
      [
        [Time.new(2025, 8, 23, 12, 0, 0, "+00:00"), Time.new(2025, 8, 25, 12, 0, 0, "+00:00"), Time.new(2025, 8, 27, 12, 0, 0, "+00:00"), 2.days, "2025.08.27"],
        [Time.new(2025, 8, 23, 12, 0, 0, "+00:00"), Time.new(2025, 8, 30, 12, 0, 0, "+00:00"), Time.new(2025, 9, 6, 12, 0, 0, "+00:00"), 1.week, "2025.09.06"]
      ].each do |last_run_at, ongoing_at, next_run_at, repeat_duration, expected_result|
        it "returns CalVer based on next scheduled run (#{next_run_at.strftime("%Y.%m.%d")}) after ongoing release with #{repeat_duration.inspect} duration" do
          train = nil
          component = nil

          # Create train when kickoff_at is in the future
          travel_to(last_run_at - 1.hour) do
            train = create(:train, :with_schedule,
              app:,
              version_seeded_with: "2025.01.01",
              versioning_strategy: :calver,
              repeat_duration: repeat_duration,
              kickoff_at: last_run_at)
            # Create ongoing release scheduled at ongoing_at
            ongoing_scheduled_release = create(:scheduled_release, train: train, scheduled_at: ongoing_at)
            create(:release, :on_track, train: train, scheduled_release: ongoing_scheduled_release)
            # Create next scheduled release
            create(:scheduled_release, train: train, scheduled_at: next_run_at)
          end

          # Test partway to next scheduled time (realistic for longer durations)
          test_time = ongoing_at + (next_run_at - ongoing_at) * 0.7
          travel_to(test_time) do
            component = described_class.new train
            expect(component.next_version).to eq(expected_result)
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
      context "when using CalVer strategy with no ongoing release and daily schedules" do
        [
          # [creation_time, kickoff_time, next_scheduled_time, next_next_scheduled_time, expected_version, description]
          [
            Time.new(2025, 8, 18, 8, 0, 0, "+00:00"),   # creation time
            Time.new(2025, 8, 18, 9, 0, 0, "+00:00"),   # kickoff time
            Time.new(2025, 8, 19, 9, 0, 0, "+00:00"),   # next scheduled release time
            Time.new(2025, 8, 20, 9, 0, 0, "+00:00"),   # next-next scheduled release time
            "2025.08.20",                               # expected next-next version
            "daily schedule"
          ],
          [
            Time.new(2025, 8, 30, 8, 0, 0, "+00:00"),   # creation time
            Time.new(2025, 8, 30, 9, 0, 0, "+00:00"),   # kickoff time
            Time.new(2025, 8, 31, 9, 0, 0, "+00:00"),   # next scheduled release time
            Time.new(2025, 9, 1, 9, 0, 0, "+00:00"),    # next-next scheduled release time (month boundary)
            "2025.09.01",                               # expected next-next version
            "month boundary crossing"
          ]
        ].each do |creation_time, kickoff_time, next_scheduled_time, next_next_scheduled_time, expected_version, description|
          it "returns CalVer based on next-next scheduled time for #{description}" do
            train = nil

            # Create train when kickoff_at is in the future
            travel_to(creation_time) do
              train = create(:train, :with_schedule,
                app:,
                version_seeded_with: "2025.01.01",
                versioning_strategy: :calver,
                repeat_duration: 1.day,
                kickoff_at: creation_time + 1.hour)
              # Create scheduled release
              create(:scheduled_release, train:, scheduled_at: next_scheduled_time)
            end

            # Test partway to next scheduled time (realistic for daily releases too)
            test_time = creation_time + (next_scheduled_time - creation_time) * 0.6
            travel_to(test_time) do
              component = described_class.new train
              expect(component.next_next_version).to eq(expected_version)
            end
          end
        end
      end

      context "when using CalVer strategy with no ongoing release and longer duration schedules" do
        [
          # [creation_time, kickoff_time, next_scheduled_time, next_next_scheduled_time, repeat_duration, expected_version, description]
          [
            Time.new(2025, 8, 18, 8, 0, 0, "+00:00"),   # creation time
            Time.new(2025, 8, 18, 9, 0, 0, "+00:00"),   # kickoff time
            Time.new(2025, 8, 20, 9, 0, 0, "+00:00"),   # next scheduled release time
            Time.new(2025, 8, 22, 9, 0, 0, "+00:00"),   # next-next scheduled release time
            2.days,                                      # repeat duration
            "2025.08.22",                               # expected next-next version
            "every other day schedule"
          ],
          [
            Time.new(2025, 8, 18, 8, 0, 0, "+00:00"),   # creation time
            Time.new(2025, 8, 18, 9, 0, 0, "+00:00"),   # kickoff time
            Time.new(2025, 8, 25, 9, 0, 0, "+00:00"),   # next scheduled release time
            Time.new(2025, 9, 1, 9, 0, 0, "+00:00"),    # next-next scheduled release time
            1.week,                                      # repeat duration
            "2025.09.01",                               # expected next-next version
            "weekly schedule"
          ]
        ].each do |creation_time, kickoff_time, next_scheduled_time, next_next_scheduled_time, repeat_duration, expected_version, description|
          it "returns CalVer based on next-next scheduled time for #{description}" do
            train = nil

            # Create train when kickoff_at is in the future
            travel_to(creation_time) do
              train = create(:train, :with_schedule,
                app:,
                version_seeded_with: "2025.01.01",
                versioning_strategy: :calver,
                repeat_duration: repeat_duration,
                kickoff_at: creation_time + 1.hour)
              # Create next scheduled release
              create(:scheduled_release, train:, scheduled_at: next_scheduled_time)
            end

            # Test partway to next scheduled time (realistic for longer durations)
            test_time = creation_time + (next_scheduled_time - creation_time) * 0.7
            travel_to(test_time) do
              component = described_class.new train
              expect(component.next_next_version).to eq(expected_version)
            end
          end
        end
      end
    end

    context "when using CalVer strategy with ongoing release and daily schedules" do
      [
        # [creation_time, ongoing_time, next_time, next_next_time, expected_version, description]
        [
          Time.new(2025, 8, 22, 8, 0, 0, "+00:00"),   # creation time
          Time.new(2025, 8, 23, 12, 0, 0, "+00:00"),  # ongoing release time
          Time.new(2025, 8, 24, 12, 0, 0, "+00:00"),  # next scheduled release time
          Time.new(2025, 8, 25, 12, 0, 0, "+00:00"),  # next-next scheduled release time
          "2025.08.25",                               # expected next-next version
          "daily schedule with ongoing release"
        ]
      ].each do |creation_time, ongoing_time, next_time, next_next_time, expected_version, description|
        it "returns CalVer based on next-next scheduled time for #{description}" do
          train = nil

          # Create train when kickoff_at is in the future
          travel_to(creation_time) do
            train = create(:train, :with_schedule,
              app:,
              version_seeded_with: "2025.01.01",
              versioning_strategy: :calver,
              repeat_duration: 1.day,
              kickoff_at: creation_time + 1.hour)
            # Create ongoing release
            ongoing_scheduled_release = create(:scheduled_release, train:, scheduled_at: ongoing_time)
            create(:release, :on_track, train:, scheduled_release: ongoing_scheduled_release)
            # Create next scheduled release
            create(:scheduled_release, train:, scheduled_at: next_time)
          end

          # Test partway to next scheduled time (realistic for daily releases too)
          test_time = ongoing_time + (next_time - ongoing_time) * 0.6
          travel_to(test_time) do
            component = described_class.new train
            expect(component.next_next_version).to eq(expected_version)
          end
        end
      end
    end

    context "when using CalVer strategy with ongoing release and longer duration schedules" do
      [
        # [creation_time, ongoing_time, next_time, next_next_time, repeat_duration, expected_version, description]
        [
          Time.new(2025, 8, 28, 8, 0, 0, "+00:00"),   # creation time
          Time.new(2025, 8, 29, 12, 0, 0, "+00:00"),  # ongoing release time
          Time.new(2025, 8, 31, 12, 0, 0, "+00:00"),  # next scheduled release time
          Time.new(2025, 9, 2, 12, 0, 0, "+00:00"),   # next-next scheduled release time (month boundary)
          2.days,                                      # repeat duration
          "2025.09.02",                               # expected next-next version
          "every other day with month boundary crossing"
        ]
      ].each do |creation_time, ongoing_time, next_time, next_next_time, repeat_duration, expected_version, description|
        it "returns CalVer based on next-next scheduled time for #{description}" do
          train = nil

          # Create train when kickoff_at is in the future
          travel_to(creation_time) do
            train = create(:train, :with_schedule,
              app:,
              version_seeded_with: "2025.01.01",
              versioning_strategy: :calver,
              repeat_duration: repeat_duration,
              kickoff_at: creation_time + 1.hour)
            # Create ongoing release
            ongoing_scheduled_release = create(:scheduled_release, train:, scheduled_at: ongoing_time)
            create(:release, :on_track, train:, scheduled_release: ongoing_scheduled_release)
            # Create next scheduled release
            create(:scheduled_release, train:, scheduled_at: next_time)
          end

          # Test partway to next scheduled time (realistic for longer durations)
          test_time = ongoing_time + (next_time - ongoing_time) * 0.7
          travel_to(test_time) do
            component = described_class.new train
            expect(component.next_next_version).to eq(expected_version)
          end
        end
      end
    end
  end
end

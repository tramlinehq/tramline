require "rails_helper"

describe Queries::ReleaseSummary, type: :model do
  describe "#all" do
    it "returns nil when cache is not warmed" do
      app = create(:app, :android)
      train = create(:train, app:)
      release = create(:release, :with_no_platform_runs, train:)

      actual = described_class.all(release_id: release.id)
      expect(actual).to be_nil
    end

    it "returns summary when cache is warmed" do
      freeze_time do
        app = create(:app, :android)
        train = create(:train, app:)
        release_platform = create(:release_platform, app:, train:)
        step = create(:step, :release, :with_deployment, release_platform:)
        deployment = create(:deployment, :with_production_channel, :with_google_play_store, step:)
        release = create(:release, :with_no_platform_runs, train:)
        release_platform_run = create(:release_platform_run, release:, release_platform:)
        step_run = create(:step_run, :success, step: step, release_platform_run:)
        drun = create(:deployment_run, :released, step_run:, deployment:)
        drun.event_stamp_now!(reason: :release_started, kind: :notice, data: drun.send(:stamp_data))
        described_class.warm(release.id)
        actual = described_class.all(release.id)
        expect(actual[:overall].attributes["version"]).to eq(release.release_version)
        expect(actual[:pull_requests]).to eq([])
        expect(actual[:steps_summary].all[0].attributes).to eq({"builds_created_count" => 1,
                                                                "duration" => 0.seconds,
                                                                "ended_at" => Time.current,
                                                                "name" => step.name,
                                                                "phase" => "release",
                                                                "platform" => "Android",
                                                                "platform_raw" => "android",
                                                                "started_at" => Time.current})
        expect(actual[:store_versions].all[0].attributes).to eq({"build_number" => step_run.build_number,
                                                                 "built_at" => Time.current,
                                                                 "platform" => "Android",
                                                                 "staged_rollouts" => [],
                                                                 "submitted_at" => Time.current,
                                                                 "release_started_at" => Time.current,
                                                                 "version" => step_run.build_version})
      end
    end
  end
end

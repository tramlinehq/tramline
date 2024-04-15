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
        create_deployment_run_tree(:android,
          :released,
          deployment_traits: [:with_production_channel],
          release_traits: [:with_no_platform_runs],
          step_traits: [:release],
          step_run_traits: [:success]) => { step:, release:, step_run:, deployment_run: }
        deployment_run.event_stamp_now!(reason: :release_started, kind: :notice, data: deployment_run.send(:stamp_data))
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

    it "returns team stability summary when teams exist for the organization" do
      org = create(:organization)
      team = org.teams.create!(name: "Team 1")
      create_deployment_run_tree(:android,
        :released,
        deployment_traits: [:with_production_channel],
        release_traits: [:with_no_platform_runs],
        step_traits: [:release],
        step_run_traits: [:success]) => { app:, step:, release:, step_run:, deployment_run: }
      app.update!(organization: org)
      stability_commits = create_list(:commit, 3, release:)
      deployment_run.event_stamp_now!(reason: :release_started, kind: :notice, data: deployment_run.send(:stamp_data))
      described_class.warm(release.id)
      actual = described_class.all(release.id)
      expect(actual[:overall].attributes["version"]).to eq(release.release_version)
      expect(actual[:team_stability_commits]).to eq({"Unknown" => stability_commits.size, team.name => 0})
    end

    it "returns reldex when release index exists" do
      create_deployment_run_tree(:android,
        :released,
        deployment_traits: [:with_production_channel],
        release_traits: [:with_no_platform_runs],
        step_traits: [:release],
        step_run_traits: [:success]) => { step:, train:, release:, step_run:, deployment_run: }

      reldex = create(:release_index, train:)
      deployment_run.event_stamp_now!(reason: :release_started, kind: :notice, data: deployment_run.send(:stamp_data))
      described_class.warm(release.id)
      actual = described_class.all(release.id)

      score = actual[:reldex]
      expect(score.grade).to eq(:mediocre)
      expect(score.value).to eq(0.55)
      expect(score.release_index.id).to eq(reldex.id)
      expect(score.components.map(&:value)).to match_array([0.0, 0.075, 0.075, 0.1, 0.15, 0.15])
    end
  end
end

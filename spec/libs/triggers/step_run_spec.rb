require "rails_helper"

describe Triggers::StepRun do
  describe ".call" do
    let(:train) { create(:train, version_seeded_with: "1.0") }
    let(:release_platform) { train.release_platforms.first }
    let(:step) { create(:step, :with_deployment, release_platform:) }
    let(:release) { create(:release, :with_no_platform_runs, :on_track, train:) }
    let(:release_platform_run) { create(:release_platform_run, release:, release_platform:, release_version: "1.1") }
    let(:commit) { create(:commit, release:) }

    it "corrects the release platform run version if train has moved ahead" do
      train.update!(version_current: "1.1")
      expect { described_class.call(step, commit, release_platform_run) }.to change(release_platform_run, :release_version).from("1.1").to("1.2")
    end

    it "does nothing if train has not moved ahead" do
      expect { described_class.call(step, commit, release_platform_run) }.not_to change(release_platform_run, :release_version)
    end

    it "creates step run" do
      expect { described_class.call(step, commit, release_platform_run) }.to change { release_platform_run.step_runs.count }.by(1)
    end

    context "when upcoming release" do
      let(:ongoing_release) { create(:release, :with_no_platform_runs, :on_track, train:) }
      let(:ongoing_release_platform_run) { create(:release_platform_run, release: ongoing_release, release_platform:, release_version: "1.1") }
      let(:release) { create(:release, :with_no_platform_runs, :on_track, train:) }
      let(:release_platform_run) { create(:release_platform_run, release:, release_platform:, release_version: "1.2") }

      it "corrects the release platform run version if ongoing release has moved ahead" do
        ongoing_release_platform_run.update!(release_version: "1.3")
        expect { described_class.call(step, commit, release_platform_run) }.to change(release_platform_run, :release_version).from("1.2").to("1.4")
      end

      it "does nothing if ongoing release has not moved ahead" do
        expect { described_class.call(step, commit, release_platform_run) }.not_to change(release_platform_run, :release_version)
      end
    end

    context "when proper semver" do
      let(:train) { create(:train, version_seeded_with: "1.1.0") }
      let(:release_platform) { train.release_platforms.first }
      let(:step) { create(:step, :with_deployment, release_platform:) }
      let(:release) { create(:release, :with_no_platform_runs, :on_track, train:) }
      let(:release_platform_run) { create(:release_platform_run, release:, release_platform:, release_version: "1.1.0") }
      let(:commit) { create(:commit, release:) }

      it "does nothing if train has moved ahead" do
        train.update!(version_current: "1.1.4")
        expect { described_class.call(step, commit, release_platform_run) }.not_to change(release_platform_run, :release_version).from("1.1.0")
      end
    end
  end
end

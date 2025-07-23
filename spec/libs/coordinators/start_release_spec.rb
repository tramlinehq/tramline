# frozen_string_literal: true

require "rails_helper"

describe Coordinators::StartRelease do
  describe ".call" do
    let(:train) { create(:train, version_seeded_with: "1.1") }
    let(:release_platform) { train.release_platforms.first }
    let(:branch_name) { Faker::Hacker.noun }
    let(:tag_name) { Faker::Hacker.noun }
    let(:github_api_double) { instance_double(Installations::Github::Api) }
    let(:github_jwt_double) { instance_double(Installations::Github::Jwt) }

    before do
      create(:release, :finished, train:, branch_name:, tag_name:)
      allow_any_instance_of(GooglePlayStoreIntegration).to receive(:draft_check?).and_return(false)
      allow(Installations::Github::Jwt).to receive(:new).and_return(github_jwt_double)
      allow(Installations::Github::Api).to receive(:new).and_return(github_api_double)
      allow(github_api_double).to receive(:diff?).and_return(true)
    end

    it "creates a new release" do
      expect {
        described_class.call(train.reload, release_type: "release")
      }.to change { train.reload.releases.count }.by(1)
    end

    it "sets the release type" do
      described_class.call(train.reload, release_type: "release")
      expect(train.reload.releases.last.release_type).to eq("release")
    end

    describe "#new_release_version" do
      context "when no existing releases" do
        {"1.2.3" => {major: "2.0.0", minor: "1.3.0"},
         "1.2" => {major: "2.0", minor: "1.3"}}.each do |ver, expect|
          it "minor bump: sets the original_release_version to next version of the train" do
            train = create(:train, version_seeded_with: ver)

            new_release = described_class.call(train.reload, release_type: "release")
            expect(new_release.original_release_version).to eq(expect[:minor])
          end

          it "major bump: sets the original_release_version to next version of the train" do
            train = create(:train, version_seeded_with: ver)

            new_release = described_class.call(train.reload, release_type: "release", has_major_bump: true)
            expect(new_release.original_release_version).to eq(expect[:major])
          end

          it "fixed version: sets the original_release_version to train's current version" do
            train = create(:train, version_seeded_with: ver, freeze_version: true)

            new_release = described_class.call(train.reload, release_type: "release")
            expect(new_release.original_release_version).to eq(ver)
          end

          it "sets the original_release_version to the custom_version" do
            train = create(:train, version_seeded_with: ver)

            new_release = described_class.call(train.reload, release_type: "release", custom_version: "2.0.0")
            expect(new_release.original_release_version).to eq("2.0.0")
          end
        end
      end

      context "when new release is hotfix" do
        it "patch bump: sets the original_release_version to the next version of a the previous good run" do
          train = create(:train, :with_almost_trunk, :with_no_platforms, :active, version_seeded_with: "1.2.3")
          release = create(:release, :finished, :with_no_platform_runs, train:)
          release_platform = create(:release_platform, train:)
          _finished_release_run = create(:release_platform_run, release:, release_platform:, release_version: "1.2.3")
          allow(github_api_double).to receive(:branch_exists?).and_return(true)

          hotfix_release = described_class.call(train.reload, release_type: "hotfix")
          expect(hotfix_release.original_release_version).to eq("1.2.4")
        end

        it "minor bump: sets the original_release_version to the next version of a the previous good run" do
          train = create(:train, :with_almost_trunk, :with_no_platforms, :active, version_seeded_with: "1.2")
          release = create(:release, :finished, :with_no_platform_runs, train:)
          release_platform = create(:release_platform, train:)
          _finished_release_run = create(:release_platform_run, release:, release_platform:, release_version: "1.2")
          allow(github_api_double).to receive(:branch_exists?).and_return(true)

          hotfix_release = described_class.call(train.reload, release_type: "hotfix")
          expect(hotfix_release.original_release_version).to eq("1.3")
        end
      end

      context "when existing ongoing release" do
        {"1.2.3" => {major: "2.0.0", minor: "1.4.0"},
         "1.2" => {major: "2.0", minor: "1.4"}}.each do |ver, expect|
          before do
            allow_any_instance_of(Train).to receive(:upcoming_release_startable?).and_return(true)
            allow_any_instance_of(Train).to receive(:diff_since_last_release?).and_return(true)
          end

          it "minor bump: sets the original_release_version to next version of the ongoing release" do
            train = create(:train, version_seeded_with: ver)
            _ongoing_release = create(:release, :on_track, train:)

            new_release = described_class.call(train.reload, release_type: "release")

            expect(new_release.original_release_version).to eq(expect[:minor])
          end

          it "major bump: sets the original_release_version to next version of the ongoing release" do
            train = create(:train, version_seeded_with: ver)
            _ongoing_release = create(:release, :on_track, train:)

            new_release = described_class.call(train.reload, release_type: "release", has_major_bump: true)

            expect(new_release.original_release_version).to eq(expect[:major])
          end
        end
      end

      context "when existing ongoing hotfix release" do
        {"1.2.3" => {major: "2.0.0", minor: "1.4.0"},
         "1.2" => {major: "2.0", minor: "1.4"}}.each do |ver, expect|
          before do
            allow_any_instance_of(Train).to receive(:diff_since_last_release?).and_return(true)
            allow_any_instance_of(Train).to receive(:upcoming_release_startable?).and_return(true)
          end

          it "minor bump: sets the original_release_version to next version of the hotfix release" do
            train = create(:train, version_seeded_with: ver)
            old_release = create(:release, :finished, train:)
            _ongoing_release = create(:release, :on_track, :hotfix, train:, hotfixed_from: old_release)

            new_release = described_class.call(train.reload, release_type: "release")

            expect(new_release.original_release_version).to eq(expect[:minor])
          end

          it "major bump: sets the original_release_version to next version of the hotfix release" do
            train = create(:train, version_seeded_with: ver)
            old_release = create(:release, :finished, train:)
            _ongoing_release = create(:release, :on_track, :hotfix, train:, hotfixed_from: old_release)

            new_release = described_class.call(train.reload, release_type: "release", has_major_bump: true)

            expect(new_release.original_release_version).to eq(expect[:major])
          end
        end
      end

      context "when train has patch_version_bump_only" do
        {"1.2.3" => {major: "2.0.0", minor: "1.2.4"},
         "1.2" => {major: "2.0", minor: "1.3"}}.each do |ver, expect|
          it "minor bump: sets the original_release_version to next version of the train with patch bump only for proper" do
            train = create(:train, version_seeded_with: ver, patch_version_bump_only: true)

            new_release = described_class.call(train.reload, release_type: "release")
            expect(new_release.original_release_version).to eq(expect[:minor])
          end

          it "major bump: sets the original_release_version to next version of the train with major bump" do
            train = create(:train, version_seeded_with: ver, patch_version_bump_only: true)

            new_release = described_class.call(train.reload, release_type: "release", has_major_bump: true)
            expect(new_release.original_release_version).to eq(expect[:major])
          end
        end
      end
    end

    context "with hotfixes" do
      it "sets the hotfixed_from" do
        allow(github_api_double).to receive(:branch_exists?).and_return(true)
        last_finished_release = train.releases.finished.sole
        new_hotfix_release = described_class.call(train.reload, release_type: "hotfix")

        expect(new_hotfix_release.hotfixed_from).to eq(last_finished_release)
      end

      it "sets the new_hotfix_branch" do
        allow(github_api_double).to receive(:tag_exists?).and_return(true)

        freeze_time do
          date = Time.current.strftime("%Y-%m-%d")
          new_hotfix_release = described_class.call(train, release_type: "hotfix", new_hotfix_branch: true)
          expect(new_hotfix_release.branch_name).to eq("hotfix/train/#{date}")
        end
      end

      it "fails hotfix release trigger if source tag does not exist" do
        allow(github_api_double).to receive(:tag_exists?).and_return(false)

        expect {
          described_class.call(train, release_type: "hotfix", new_hotfix_branch: true)
        }.to raise_error("Could not kickoff a hotfix because the source tag does not exist")
      end

      it "fails hotfix release trigger if source branch does not exist" do
        allow(github_api_double).to receive(:branch_exists?).and_return(false)

        expect {
          described_class.call(train, release_type: "hotfix")
        }.to raise_error("Could not kickoff a hotfix because the source release branch does not exist")
      end

      it "fails release creation if the platform is invalid" do
        allow(github_api_double).to receive(:branch_exists?).and_return(true)

        expect {
          described_class.call(train, release_type: "hotfix", hotfix_platform: "invalid_platform")
        }.to raise_error("Hotfix platform - invalid_platform is not valid!")
      end

      it "refreshes the reports for the hotfixed release" do
        allow(github_api_double).to receive(:branch_exists?).and_return(true)
        allow(RefreshReportsJob).to receive(:perform_async)
        last_finished_release = train.releases.finished.sole
        described_class.call(train, release_type: "hotfix")

        expect(RefreshReportsJob).to have_received(:perform_async).with(last_finished_release.id)
      end
    end

    context "with release creation failure" do
      it "raises an error when the custom version is invalid" do
        expect {
          described_class.call(train, custom_version: "1.2.3-abc")
        }.to raise_error("Invalid custom release version! Please use a SemVer-like x.y.z format based on your configured versioning strategy.")
      end

      it "raises an error when the train is inactive" do
        train.update!(status: Train.statuses[:inactive])
        expect {
          described_class.call(train)
        }.to raise_error("Cannot start a train that is not active!")
      end

      it "raises an error when there is an existing upcoming release and the release is not a hotfix" do
        _ongoing_release = create(:release, :on_track, train:)
        _upcoming_release = create(:release, :on_track, train:)
        expect {
          described_class.call(train, automatic: true)
        }.to raise_error("No more releases can be started until the ongoing release is finished!")
      end

      it "raises an error when the upcoming release is not startable" do
        _ongoing_release = create(:release, :on_track, train:)
        expect {
          described_class.call(train)
        }.to raise_error("Upcoming releases are not allowed for your train.")
      end
    end
  end
end

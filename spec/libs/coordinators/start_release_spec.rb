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

    context "when hotfixes" do
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
        allow(RefreshReportsJob).to receive(:perform_later)
        last_finished_release = train.releases.finished.sole
        described_class.call(train, release_type: "hotfix")

        expect(RefreshReportsJob).to have_received(:perform_later).with(last_finished_release.id)
      end
    end

    context "when failure" do
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

      it "raises an error when there is an existing ongoing release and the release is automatic" do
        _existing_release = create(:release, :on_track, train:)
        expect {
          described_class.call(train, automatic: true)
        }.to raise_error("No more releases can be started until the ongoing release is finished!")
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

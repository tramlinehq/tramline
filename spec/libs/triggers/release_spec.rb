require "rails_helper"

describe Triggers::Release do
  describe ".call" do
    let(:train) { create(:train, version_seeded_with: "1.1") }
    let(:release_platform) { train.release_platforms.first }
    let(:branch_name) { Faker::Hacker.noun }
    let(:tag_name) { Faker::Hacker.noun }
    let(:github_api_double) { instance_double(Installations::Github::Api) }
    let(:github_jwt_double) { instance_double(Installations::Github::Jwt) }
    let(:release) { create(:release, :finished, :with_no_platform_runs, train:, branch_name:, tag_name:) }

    before do
      create(:step, :release, :with_deployment, release_platform:)
      create(:release_platform_run, release:, release_platform:)
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
        described_class.call(train.reload, release_type: "hotfix")
        new_hotfix_release = train.reload.releases.created.first

        expect(new_hotfix_release.hotfixed_from).to eq(release)
      end

      it "sets the new_hotfix_branch" do
        allow(github_api_double).to receive(:tag_exists?).and_return(true)

        freeze_time do
          date = Time.current.strftime("%Y-%m-%d")
          described_class.call(train.reload, release_type: "hotfix", new_hotfix_branch: true)
          new_hotfix_release = train.reload.releases.created.first
          expect(new_hotfix_release.branch_name).to eq("hotfix/train/#{date}")
        end
      end

      it "fails hotfix release trigger if source tag does not exist" do
        allow(github_api_double).to receive(:tag_exists?).and_return(false)

        response = described_class.call(train.reload, release_type: "hotfix", new_hotfix_branch: true)
        expect(response.body).to eq("Could not kickoff a hotfix because the source tag does not exist")
      end

      it "fails hotfix release trigger if source branch does not exist" do
        allow(github_api_double).to receive(:branch_exists?).and_return(false)

        response = described_class.call(train.reload, release_type: "hotfix")
        expect(response.body).to eq("Could not kickoff a hotfix because the source release branch does not exist")
      end
    end
  end
end

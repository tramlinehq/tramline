# frozen_string_literal: true

require "rails_helper"

describe Triggers::PreRelease::AlmostTrunk do
  describe ".call" do
    let(:working_branch) { "main" }
    let(:release_tag_name) { Faker::Lorem.word }

    context "when default release branch" do
      let(:train) { create(:train, working_branch: working_branch) }
      let(:release) { create(:release, train: train, tag_name: release_tag_name) }
      let(:release_branch) { release.release_branch }

      before do
        allow(Triggers::Branch).to receive(:call)
      end

      it "creates a new release branch" do
        described_class.call(release, release_branch)

        expect(Triggers::Branch).to have_received(:call).with(release, working_branch, release_branch, :branch, anything, anything)
      end

      it "uses the hotfix ref for a hotfix release when creating the release branch" do
        hotfix_release = create(:release, :hotfix, hotfixed_from: release, new_hotfix_branch: true, train: train)
        hotfix_release_branch = hotfix_release.release_branch

        described_class.call(hotfix_release, hotfix_release_branch)

        expect(Triggers::Branch).to have_received(:call).with(hotfix_release, release_tag_name, hotfix_release_branch, :tag, anything, anything)
      end

      it "does not use the hotfix ref if there is no new hotfix branch" do
        hotfix_release = create(:release, :hotfix, hotfixed_from: release, new_hotfix_branch: false, train: train)

        described_class.call(hotfix_release, release_branch)

        expect(Triggers::Branch).to have_received(:call).with(hotfix_release, working_branch, release_branch, :branch, anything, anything)
      end
    end

    context "when version bump is enabled" do
      let(:train) { create(:train, working_branch: working_branch, version_bump_enabled: true, version_bump_file_paths: ["pubspec.yaml"]) }
      let(:release) { create(:release, train: train, tag_name: release_tag_name) }
      let(:commit) { create(:commit, release:) }
      let(:release_branch) { release.release_branch }
      let(:hotfix_release) { create(:release, :hotfix, hotfixed_from: release, new_hotfix_branch: true, train: train) }
      let(:hotfix_release_branch) { hotfix_release.release_branch }

      it "triggers version bump if its enabled" do
        allow(Triggers::VersionBump).to receive(:call).and_return(GitHub::Result.new)
        allow(Triggers::Branch).to receive(:call).and_return(GitHub::Result.new)
        create(:pull_request, release:, commit:, phase: :pre_release, kind: :version_bump)

        described_class.call(release, release_branch)

        expect(Triggers::VersionBump).to have_received(:call).with(release)
      end

      it "creates a new release branch from the version bump commit" do
        allow(Triggers::VersionBump).to receive(:call).and_return(GitHub::Result.new)
        allow(Triggers::Branch).to receive(:call).and_return(GitHub::Result.new)
        create(:pull_request, release:, commit:, kind: :version_bump, phase: :pre_release, merge_commit_sha: commit.commit_hash)

        described_class.call(release, release_branch)

        expect(Triggers::Branch).to have_received(:call).with(release, commit.commit_hash, release_branch, :commit, anything, anything)
      end

      it "defaults to the working branch if no version bump commit is found" do
        allow(Triggers::VersionBump).to receive(:call).and_return(GitHub::Result.new)
        allow(Triggers::Branch).to receive(:call).and_return(GitHub::Result.new)
        create(:pull_request, release:, commit:, phase: :pre_release, kind: :version_bump merge_commit_sha: nil)

        described_class.call(release, release_branch)

        expect(Triggers::Branch).to have_received(:call).with(release, working_branch, release_branch, :branch, anything, anything)
      end

      it "does not version bump if it is a hotfix release" do
        allow(Triggers::VersionBump).to receive(:call)
        allow(Triggers::Branch).to receive(:call)
        hotfix_release = create(:release, :hotfix, hotfixed_from: release, new_hotfix_branch: true, train: train)
        hotfix_release_branch = hotfix_release.release_branch

        described_class.call(hotfix_release, hotfix_release_branch)

        expect(Triggers::VersionBump).not_to have_received(:call)
        expect(Triggers::Branch).to have_received(:call).with(hotfix_release, release_tag_name, hotfix_release_branch, :tag, anything, anything)
      end
    end
  end
end

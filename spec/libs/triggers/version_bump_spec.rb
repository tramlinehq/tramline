# frozen_string_literal: true

require "rails_helper"

describe Triggers::VersionBump do
  def setup_mocks(train, vcs_provider_dbl, project_file, updated_contents_file)
    allow(train).to receive(:vcs_provider).and_return(vcs_provider_dbl)
    allow(vcs_provider_dbl).to receive_messages(get_file_content: File.read(project_file), update_file!: File.read(updated_contents_file))
    allow(Triggers::Branch).to receive(:call).and_return(GitHub::Result.new)
    allow(Triggers::PullRequest).to receive(:create_and_merge!).and_return(GitHub::Result.new)
  end

  describe ".call" do
    it "does not create a version bump branch if version bump is disabled" do
      allow(Triggers::Branch).to receive(:call)
      train = create(:train)
      release = create(:release, train:)

      described_class.call(release)

      expect(Triggers::Branch).not_to have_received(:call)
    end

    context "when a version bump PR is attempted" do
      let(:project_file) { "spec/fixtures/project_files/build.1.0.0.gradle" }
      let(:updated_contents_file) { "spec/fixtures/project_files/build.1.2.0.gradle" }
      let(:train) { create(:train, version_seeded_with: "1.1.0", version_bump_enabled: true, version_bump_file_paths: [project_file]) }
      let(:release) { create(:release, train:) }
      let(:vcs_provider_dbl) { instance_double(GithubIntegration) }
      let(:expected_new_branch) { "version-bump-#{release.release_version}-#{release.slug}" }

      it "creates the version bump branch" do
        setup_mocks(train, vcs_provider_dbl, project_file, updated_contents_file)

        described_class.call(release)

        expected_new_branch = "version-bump-#{release.release_version}-#{release.slug}"
        expect(Triggers::Branch).to have_received(:call).with(release, train.working_branch, expected_new_branch, :branch, anything, anything).once
      end

      it "fetches the file content from the vcs provider" do
        setup_mocks(train, vcs_provider_dbl, project_file, updated_contents_file)

        described_class.call(release)

        expect(vcs_provider_dbl).to have_received(:get_file_content).with(expected_new_branch, project_file).once
      end

      it "updates the file content if there is a diff" do
        setup_mocks(train, vcs_provider_dbl, project_file, updated_contents_file)

        described_class.call(release)

        commit_title = "Bump version to #{release.release_version} in #{project_file}"
        expect(vcs_provider_dbl).to have_received(:update_file!).with(expected_new_branch, project_file, anything, commit_title, anything).once
      end

      it "does not update the file content if there is no diff" do
        setup_mocks(train, vcs_provider_dbl, project_file, updated_contents_file)

        allow(release).to receive(:release_version).and_return("1.0.0")

        described_class.call(release)

        expect(vcs_provider_dbl).not_to have_received(:update_file!).with(anything, anything, anything, anything, anything)
      end

      it "creates the version bump PR if it doesn't exist" do
        setup_mocks(train, vcs_provider_dbl, project_file, updated_contents_file)

        described_class.call(release)

        expected_description = <<~BODY
          🎉 A new release #{release.release_version} has kicked off!

          This PR updates the version number in `#{project_file}` to prepare for our #{release.release_version} release.

          All aboard the release train!
        BODY
        expect(Triggers::PullRequest).to have_received(:create_and_merge!).with(
          release: release,
          new_pull_request_attrs: anything,
          to_branch_ref: train.working_branch,
          from_branch_ref: expected_new_branch,
          existing_pr: nil,
          title: "Bump version to #{release.release_version}",
          description: expected_description,
          error_result_on_auto_merge: true
        ).once
      end
    end

    context "when a version bump PR is attempted and versions can be updated" do
      let(:vcs_provider_dbl) { instance_double(GithubIntegration) }

      it "updates the gradle file" do
        project_file = "spec/fixtures/project_files/build.1.0.0.gradle"
        updated_contents_file = "spec/fixtures/project_files/build.1.2.0.gradle"
        updated_contents = File.read(updated_contents_file)
        train = create(:train, version_seeded_with: "1.1.0", version_bump_enabled: true, version_bump_file_paths: [project_file])
        release = create(:release, train:)
        setup_mocks(train, vcs_provider_dbl, project_file, updated_contents_file)

        described_class.call(release)

        expect(vcs_provider_dbl).to have_received(:update_file!).with(anything, project_file, updated_contents, anything, anything).once
      end

      it "updates the gradle kotlin file" do
        project_file = "spec/fixtures/project_files/build.1.0.0.gradle.kts"
        updated_contents_file = "spec/fixtures/project_files/build.1.2.0.gradle.kts"
        updated_contents = File.read(updated_contents_file)
        train = create(:train, version_seeded_with: "1.1.0", version_bump_enabled: true, version_bump_file_paths: [project_file])
        release = create(:release, train:)
        setup_mocks(train, vcs_provider_dbl, project_file, updated_contents_file)

        described_class.call(release)

        expect(vcs_provider_dbl).to have_received(:update_file!).with(anything, project_file, updated_contents, anything, anything).once
      end

      it "updates the flutter pubspec file" do
        project_file = "spec/fixtures/project_files/build.1.0.0.pubspec.yaml"
        updated_contents_file = "spec/fixtures/project_files/build.1.2.0.pubspec.yaml"
        updated_contents = File.read(updated_contents_file)
        train = create(:train, version_seeded_with: "1.1.0", version_bump_enabled: true, version_bump_file_paths: [project_file])
        release = create(:release, train:)
        setup_mocks(train, vcs_provider_dbl, project_file, updated_contents_file)

        described_class.call(release)

        expect(vcs_provider_dbl).to have_received(:update_file!).with(anything, project_file, updated_contents, anything, anything).once
      end
    end

    describe "#update_gradle_version" do
      let(:release) { create(:release) }

      before do
        allow(release).to receive(:release_version).and_return("1.2.0")
      end

      [
        ['versionName "1.0.0"', 'versionName "1.2.0"'],
        ['versionName"1.0.0"', 'versionName"1.0.0"'],
        ['versionName      "1.0.0"', 'versionName "1.2.0"'],
        ["versionName 1.0.0", "versionName 1.0.0"],
        ["versionName 1", "versionName 1"],
        ["versionName 1.", "versionName 1."],
        ["versionName 1.0", "versionName 1.0"],
        ['versionName \n\tif', 'versionName \n\tif'],
        ["", ""],
        ["versionCode 1", "versionCode 1"]
      ].each do |input, expected|
        it "matches against <#{input}>" do
          expect(described_class.new(release).update_gradle_version(input)).to eq(expected)
        end
      end
    end

    describe "#update_gradle_kts_version" do
      let(:release) { create(:release) }

      before do
        allow(release).to receive(:release_version).and_return("1.2.0")
      end

      [
        ['versionName = "1.0.0"', 'versionName = "1.2.0"'],
        ['versionName="1.0.0"', 'versionName = "1.2.0"'],
        ['versionName= "1.0.0"', 'versionName = "1.2.0"'],
        ['versionName ="1.0.0"', 'versionName = "1.2.0"'],
        ['versionName   =    "1.0.0"', 'versionName = "1.2.0"'],
        ["versionName = 1.0.0", "versionName = 1.0.0"],
        ["versionName = 1", "versionName = 1"],
        ["versionName = 1.", "versionName = 1."],
        ["versionName = 1.0", "versionName = 1.0"],
        ['versionName = \n\tif', 'versionName = \n\tif'],
        ["", ""],
        ["versionCode = 1", "versionCode = 1"]
      ].each do |input, expected|
        it "matches against <#{input}>" do
          expect(described_class.new(release).update_gradle_kts_version(input)).to eq(expected)
        end
      end
    end

    describe "#update_pubspec_version" do
      let(:release) { create(:release) }

      before do
        allow(release).to receive(:release_version).and_return("1.2.0")
      end

      [
        ["version: 1.0.0+1", "version: 1.2.0+1"],
        ["version: 1.0.0", "version: 1.2.0"],
        ['version: "1.0.0"', "version: 1.2.0"],
        ['version: "1.0.0+1"', "version: 1.2.0+1"],
        ["version:", "version:"],
        ["version: ", "version: "],
        ["version:        ", "version:        "],
        ["vershion: 1.0.0+1", "vershion: 1.0.0+1"],
        ["", ""]
      ].each do |input, expected|
        it "matches against <#{input}>" do
          expect(described_class.new(release).update_pubspec_version(input)).to eq(expected)
        end
      end
    end
  end
end

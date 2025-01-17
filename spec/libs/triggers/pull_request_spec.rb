require "rails_helper"

describe Triggers::PullRequest do
  let(:app) { create(:app, :android) }
  let(:train) { create(:train, app:) }
  let(:release) { create(:release, train:) }
  let(:working_branch) { Faker::Lorem.word }
  let(:release_branch) { Faker::Lorem.word }
  let(:pr_title) { Faker::Lorem.word }
  let(:pr_description) { Faker::Lorem.word }
  let(:repo_integration) { instance_double(Installations::Github::Api) }
  let(:repo_name) { app.config.code_repository_name }
  let(:no_diff_error) { Installations::Error.new("Should not create a Pull Request without a diff", reason: :pull_request_without_commits) }

  before do
    allow(Installations::Github::Api).to receive(:new).and_return(repo_integration)
  end

  describe ".create_and_merge!" do
    let(:create_payload) {
      File.read("spec/fixtures/github/pull_request.json")
        .then { |pr| JSON.parse(pr) }
        .then { |parsed_pr| Installations::Response::Keys.transform([parsed_pr], GithubIntegration::PR_TRANSFORMATIONS) }
        .first
    }
    let(:merge_payload) { JSON.parse(File.read("spec/fixtures/github/merge_pull_request.json")).with_indifferent_access }

    it "creates a PR for the release" do
      allow(repo_integration).to receive_messages(create_pr!: create_payload, merge_pr!: merge_payload, enable_auto_merge: true)

      result = described_class.create_and_merge!(
        release: release,
        new_pull_request: release.pull_requests.post_release.open.build,
        to_branch_ref: working_branch,
        from_branch_ref: release_branch,
        title: pr_title,
        description: pr_description
      )
      namespaced_release_branch = "#{release.train.app.config.code_repo_namespace}:#{release_branch}"

      expect(repo_integration).to have_received(:create_pr!).with(repo_name, working_branch, namespaced_release_branch, pr_title, pr_description, GithubIntegration::PR_TRANSFORMATIONS)
      expect(result.ok?).to be(true)
      expect(release.reload.pull_requests.size).to eq(1)
    end

    it "creates a patch PR for the commit" do
      allow(repo_integration).to receive_messages(cherry_pick_pr: create_payload, merge_pr!: merge_payload, enable_auto_merge: true)
      commit = create(:commit, release:)
      patch_branch = "patch-main-#{commit.commit_hash}"

      result = described_class.create_and_merge!(
        release: release,
        new_pull_request: commit.build_pull_request(release:, phase: :ongoing),
        to_branch_ref: working_branch,
        from_branch_ref: patch_branch,
        title: pr_title,
        description: pr_description,
        patch_pr: true,
        patch_commit: commit
      )

      expect(repo_integration).to have_received(:cherry_pick_pr).with(repo_name, working_branch, commit.commit_hash, patch_branch, pr_title, pr_description, GithubIntegration::PR_TRANSFORMATIONS)
      expect(result.ok?).to be(true)
      expect(commit.reload.pull_request).to be_present
    end

    it "merges the PR" do
      allow(repo_integration).to receive_messages(create_pr!: create_payload, merge_pr!: merge_payload, enable_auto_merge: true)

      result = described_class.create_and_merge!(
        release: release,
        new_pull_request: release.pull_requests.post_release.open.build,
        to_branch_ref: working_branch,
        from_branch_ref: release_branch,
        title: pr_title,
        description: pr_description
      )
      expect(repo_integration).to have_received(:merge_pr!).with(repo_name, result.value!.number)
      expect(result.ok?).to be(true)
      expect(release.reload.pull_requests.size).to eq(1)
    end

    it "enables auto merge if merge fails" do
      allow(repo_integration).to receive_messages(cherry_pick_pr: create_payload, enable_auto_merge: true)
      allow(repo_integration).to receive(:merge_pr!).and_raise(Installations::Error.new("Failed to merge the Pull Request", reason: :pull_request_not_mergeable))
      commit = create(:commit, release:)
      patch_branch = "patch-main-#{commit.commit_hash}"

      result = described_class.create_and_merge!(
        release: release,
        new_pull_request: commit.build_pull_request(release:, phase: :ongoing),
        to_branch_ref: working_branch,
        from_branch_ref: patch_branch,
        title: pr_title,
        description: pr_description,
        patch_pr: true,
        patch_commit: commit
      )

      created_pr = commit.reload.pull_request

      expect(repo_integration).to have_received(:cherry_pick_pr).with(repo_name, working_branch, commit.commit_hash, patch_branch, pr_title, pr_description, GithubIntegration::PR_TRANSFORMATIONS)
      expect(repo_integration).to have_received(:merge_pr!).with(repo_name, created_pr.number)
      expect(repo_integration).to have_received(:enable_auto_merge).with(app.config.code_repo_namespace, app.config.code_repo_name_only, created_pr.number)
      expect(result.ok?).to be(true)
      expect(created_pr.closed?).to be(false)
    end

    it "does not create PR if the PR does not have a diff to create" do
      allow(repo_integration).to receive(:create_pr!).and_raise(no_diff_error)

      result = described_class.create_and_merge!(
        release: release,
        new_pull_request: release.pull_requests.post_release.open.build,
        to_branch_ref: working_branch,
        from_branch_ref: release_branch,
        title: pr_title,
        description: pr_description,
        allow_without_diff: true
      )
      namespaced_release_branch = "#{release.train.app.config.code_repo_namespace}:#{release_branch}"

      expect(repo_integration).to have_received(:create_pr!).with(repo_name, working_branch, namespaced_release_branch, pr_title, pr_description, GithubIntegration::PR_TRANSFORMATIONS)
      expect(result.ok?).to be(true)
      expect(release.reload.pull_requests.size).to eq(0)
    end

    it "returns an unsuccessful result if the PR does not have a diff to create and allow without diff is false" do
      allow(repo_integration).to receive(:create_pr!).and_raise(no_diff_error)

      result = described_class.create_and_merge!(
        release: release,
        new_pull_request: release.pull_requests.post_release.open.build,
        to_branch_ref: working_branch,
        from_branch_ref: release_branch,
        title: pr_title,
        description: pr_description,
        allow_without_diff: false
      )
      namespaced_release_branch = "#{release.train.app.config.code_repo_namespace}:#{release_branch}"

      expect(repo_integration).to have_received(:create_pr!).with(repo_name, working_branch, namespaced_release_branch, pr_title, pr_description, GithubIntegration::PR_TRANSFORMATIONS)
      expect(result.ok?).to be(false)
      expect(release.reload.pull_requests.size).to eq(0)
    end

    context "when auto merge is disabled" do
      let(:vcs_integration) { create(:integration, :with_bitbucket) }
      let(:app) { vcs_integration.app }
      let(:repo_integration) { instance_double(Installations::Bitbucket::Api) }

      before do
        allow(train).to receive(:vcs_provider).and_return(vcs_integration.providable)
        allow(Installations::Bitbucket::Api).to receive(:new).and_return(repo_integration)
      end

      it "merges the PR and closes it after merging" do
        allow(repo_integration).to receive_messages(create_pr!: create_payload, merge_pr!: merge_payload)

        result = described_class.create_and_merge!(
          release: release,
          new_pull_request: release.pull_requests.post_release.open.build,
          to_branch_ref: working_branch,
          from_branch_ref: release_branch,
          title: pr_title,
          description: pr_description
        )

        expect(result.ok?).to be(true)
        created_pr = release.reload.pull_requests.sole
        expect(repo_integration).to have_received(:create_pr!).with(repo_name, working_branch, release_branch, pr_title, pr_description, BitbucketIntegration::PR_TRANSFORMATIONS)
        expect(repo_integration).to have_received(:merge_pr!).with(repo_name, created_pr.number)
        expect(created_pr.closed?).to be(true)
      end

      it "does not close the PR if the merge fails" do
        allow(repo_integration).to receive(:create_pr!).and_return(create_payload)
        allow(repo_integration).to receive(:merge_pr!).and_raise(Installations::Error.new("Failed to merge the Pull Request", reason: :pull_request_not_mergeable))

        result = described_class.create_and_merge!(
          release: release,
          new_pull_request: release.pull_requests.post_release.open.build,
          to_branch_ref: working_branch,
          from_branch_ref: release_branch,
          title: pr_title,
          description: pr_description
        )

        created_pr = release.reload.pull_requests.sole
        expect(repo_integration).to have_received(:create_pr!).with(repo_name, working_branch, release_branch, pr_title, pr_description, BitbucketIntegration::PR_TRANSFORMATIONS)
        expect(repo_integration).to have_received(:merge_pr!)
        expect(result.ok?).to be(false)
        expect(created_pr.closed?).to be(false)
      end
    end

    context "when pr is found" do
      it "finds an existing closed PR and updates the status" do
        existing_pr = create(:pull_request, release:, state: "open", number: 1)
        existing_pr_payload =
          File.read("spec/fixtures/github/get_pr_[closed].json")
            .then { |pr| JSON.parse(pr) }
            .then { |parsed_pr| Installations::Response::Keys.transform([parsed_pr], GithubIntegration::PR_TRANSFORMATIONS) }
            .first

        allow(repo_integration).to receive(:get_pr).and_return(existing_pr_payload)
        result = described_class.create_and_merge!(
          release: release,
          to_branch_ref: working_branch,
          new_pull_request: nil,
          from_branch_ref: release_branch,
          title: pr_title,
          description: pr_description,
          allow_without_diff: true,
          existing_pr:
        )
        expect(repo_integration).to have_received(:get_pr).with(repo_name, existing_pr.number, GithubIntegration::PR_TRANSFORMATIONS)
        expect(result.ok?).to be(true)
        expect(existing_pr.reload.closed?).to be(true)
      end

      it "finds an existing PR and closes it after merging" do
        vcs_integration = create(:integration, :with_bitbucket)
        repo_integration = instance_double(Installations::Bitbucket::Api)
        allow(train).to receive(:vcs_provider).and_return(vcs_integration.providable)
        allow(Installations::Bitbucket::Api).to receive(:new).and_return(repo_integration)

        existing_pr = create(:pull_request, release:, state: "open", number: 1)
        existing_pr_payload =
          File.read("spec/fixtures/github/get_pr_[open].json")
            .then { |pr| JSON.parse(pr) }
            .then { |parsed_pr| Installations::Response::Keys.transform([parsed_pr], GithubIntegration::PR_TRANSFORMATIONS) }
            .first
        allow(repo_integration).to receive(:get_pr).and_return(existing_pr_payload)
        allow(repo_integration).to receive(:merge_pr!)

        result = described_class.create_and_merge!(
          release: release,
          new_pull_request: release.pull_requests.post_release.open.build,
          to_branch_ref: working_branch,
          from_branch_ref: release_branch,
          title: pr_title,
          description: pr_description,
          allow_without_diff: true,
          existing_pr:
        )

        expect(repo_integration).to have_received(:get_pr).with(repo_name, existing_pr.number, BitbucketIntegration::PR_TRANSFORMATIONS)
        expect(repo_integration).to have_received(:merge_pr!)
        expect(result.ok?).to be(true)
        expect(release.reload.pull_requests.closed.size).to eq(1)
      end
    end
  end
end

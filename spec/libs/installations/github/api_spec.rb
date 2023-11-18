require "rails_helper"

describe Installations::Github::Api, type: :integration do
  let(:installation_id) { Faker::String.random(length: 8) }

  before do
    token = Faker::String.random(length: 8)
    github_jwt_double = instance_double(Installations::Github::Jwt)

    allow(Installations::Github::Jwt).to receive(:new).and_return(github_jwt_double)
    allow(github_jwt_double).to receive(:get).and_return("sha")
    allow_any_instance_of(Octokit::Client).to receive(:create_app_installation_access_token).and_return(token: token)
  end

  describe "#list_repos" do
    let(:payload) { JSON.parse(File.read("spec/fixtures/github/repos.json")) }

    it "returns the transformed list of repos" do
      allow_any_instance_of(Octokit::Client).to receive(:list_app_installation_repositories).and_return(repositories: payload)
      result = described_class.new(installation_id).list_repos(GithubIntegration::REPOS_TRANSFORMATIONS)

      expected = {
        id: "1296269",
        name: "Hello-World",
        namespace: "octocat",
        full_name: "octocat/Hello-World",
        description: "This your first repo!",
        repo_url: "https://github.com/octocat/Hello-World",
        avatar_url: "https://github.com/images/error/octocat_happy.gif"
      }
      expect(result).to contain_exactly(expected)
    end
  end

  describe "#list_workflows" do
    let(:payload) { JSON.parse(File.read("spec/fixtures/github/workflows.json")).to_h.with_indifferent_access }
    let(:repo) { Faker::Lorem.characters(number: 8) }

    it "returns the transformed list of active workflows" do
      allow_any_instance_of(Octokit::Client).to receive(:workflows).and_return(payload)
      result = described_class.new(installation_id).list_workflows(repo, GithubIntegration::WORKFLOWS_TRANSFORMATIONS)

      expected = {
        id: "161335",
        name: "CI"
      }
      expect(result).to contain_exactly(expected)
    end
  end

  describe "#find_workflow_run" do
    let(:payload) { JSON.parse(File.read("spec/fixtures/github/workflow_runs.json")).to_h.with_indifferent_access }
    let(:repo) { Faker::Lorem.characters(number: 8) }

    it "returns the transformed list of active workflows" do
      workflow = Faker::Lorem.characters(number: 8)
      branch = Faker::Lorem.characters(number: 8)
      head_sha = Faker::Crypto.sha1

      allow_any_instance_of(Octokit::Client).to receive(:workflow_runs).and_return(payload)
      result =
        described_class
          .new(installation_id)
          .find_workflow_run(repo, workflow, branch, head_sha, GithubIntegration::WORKFLOW_RUN_TRANSFORMATIONS)

      expected = {
        ci_ref: 30433642,
        ci_link: "https://github.com/octo-org/octo-repo/actions/runs/30433642"
      }
      expect(result).to match(expected)
    end
  end

  describe "#create_branch!" do
    let(:payload) { JSON.parse(File.read("spec/fixtures/github/create_branch.json")).to_h.with_indifferent_access }
    let(:repo) { Faker::Lorem.characters(number: 8) }

    it "only accepts source ref as commit, branch or tag" do
      source_name = "nothing"
      new_branch_name = "new-branch"
      allow_any_instance_of(Octokit::Client).to receive(:create_ref).and_return(payload)

      expect {
        described_class
          .new(installation_id)
          .create_branch!(repo, source_name, new_branch_name, source_type: :nothing)
      }.to raise_error(ArgumentError)
    end

    it "returns the created branch from commit" do
      source_name = "aa218f56b14c9653891f9e74264a383fa43fefbd"
      new_branch_name = "featureA"
      allow_any_instance_of(Octokit::Client).to receive(:create_ref).and_return(payload)

      result =
        described_class
          .new(installation_id)
          .create_branch!(repo, source_name, new_branch_name, source_type: :commit)

      expected_branch = "refs/heads/#{new_branch_name}"
      expect(result[:ref]).to match(expected_branch)
    end
  end

  describe "#head" do
    let(:payload) { JSON.parse(File.read("spec/fixtures/github/get_ref.json")).to_h.with_indifferent_access }
    let(:commit_payload) { JSON.parse(File.read("spec/fixtures/github/get_commit.json")).to_h.with_indifferent_access }
    let(:repo) { Faker::Lorem.characters(number: 8) }

    it "returns the head sha of a branch" do
      branch_name = "refs/heads/featureA"
      allow_any_instance_of(Octokit::Client).to receive(:ref).and_return(payload)

      result =
        described_class
          .new(installation_id)
          .head(repo, branch_name)

      expected_sha = "aa218f56b14c9653891f9e74264a383fa43fefbd"
      expect(result).to match(expected_sha)
    end

    it "expects commit transformations when query for full commit object" do
      branch_name = "refs/heads/featureA"
      allow_any_instance_of(Octokit::Client).to receive(:ref).and_return(payload)

      expect {
        described_class
          .new(installation_id)
          .head(repo, branch_name, sha_only: false)
      }.to raise_error(ArgumentError)
    end

    it "returns a full commit object" do
      branch_name = "refs/heads/featureA"
      allow_any_instance_of(Octokit::Client).to receive(:ref).and_return(payload)
      allow_any_instance_of(Octokit::Client).to receive(:commit).and_return(commit_payload)

      result =
        described_class
          .new(installation_id)
          .head(repo, branch_name, sha_only: false, commit_transforms: GithubIntegration::COMMITS_TRANSFORMATIONS)

      expected = {
        url: "https://github.com/octocat/Hello-World/commit/6dcb09b5b57875f334f61aebed695e2e4193db5e",
        commit_hash: "6dcb09b5b57875f334f61aebed695e2e4193db5e",
        message: "Fix all the bugs",
        author_name: "Monalisa Octocat",
        author_email: "mona@github.com",
        author_login: "octocat",
        author_url: "https://github.com/octocat",
        timestamp: "2011-04-14T16:00:49Z",
        parents: [
          {
            url: "https://api.github.com/repos/octocat/Hello-World/commits/6dcb09b5b57875f334f61aebed695e2e4193db5e",
            sha: "6dcb09b5b57875f334f61aebed695e2e4193db5e"
          }
        ]
      }
      expect(result).to match(expected)
    end
  end
end

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
      result = described_class.new(installation_id).list_repos(GithubIntegration::LIST_REPOS_TRANSFORMATIONS)

      expected = {
        id: 1296269,
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
    let(:repo) { Faker::String.random }

    it "returns the transformed list of active workflows" do
      allow_any_instance_of(Octokit::Client).to receive(:workflows).and_return(payload)
      result = described_class.new(installation_id).list_workflows(repo, GithubIntegration::LIST_WORKFLOWS_TRANSFORMATIONS)

      expected = {
        id: 161335,
        name: "CI"
      }
      expect(result).to contain_exactly(expected)
    end
  end
end

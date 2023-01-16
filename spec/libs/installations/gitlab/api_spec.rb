require "rails_helper"

describe Installations::Gitlab::Api, type: :integration do
  let(:access_token) { Faker::String.random(length: 8) }

  describe "#list_projects" do
    let(:payload) { JSON.parse(File.read("spec/fixtures/gitlab/projects.json")) }

    it "returns the transformed list of enabled apps" do
      allow_any_instance_of(described_class).to receive(:execute).with(:get,
        "https://gitlab.com/api/v4/projects",
        {params: {membership: true}})
        .and_return(payload)
      result = described_class.new(access_token).list_projects(GitlabIntegration::REPOS_TRANSFORMATIONS)

      expected_projects = [
        {
          id: "4",
          name: "diaspora-client",
          namespace: "diaspora",
          full_name: "diaspora/diaspora-client",
          description: nil,
          repo_url: "https://gitlab.example.com/diaspora/diaspora-client",
          avatar_url: "https://gitlab.example.com/uploads/project/avatar/4/uploads/avatar.png"
        },
        {
          id: "5",
          name: "diaspora-client-again",
          namespace: "diaspora",
          full_name: "diaspora/diaspora-client-again",
          description: nil,
          repo_url: "https://gitlab.example.com/diaspora/diaspora-client-again",
          avatar_url: "https://gitlab.example.com/uploads/project/avatar/4/uploads/avatar.png"
        }
      ]
      expect(result).to contain_exactly(*expected_projects)
    end
  end
end

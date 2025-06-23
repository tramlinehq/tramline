require "rails_helper"
require "webmock/rspec"

describe Installations::Gitlab::Api, type: :integration do
  let(:access_token) { "glpat_" + SecureRandom.base58(32) }

  describe "#list_projects" do
    before do
      stub_request(:get, "https://gitlab.com/api/v4/projects")
        .with(query: {membership: true, per_page: 50})
        .to_return_json(body: fake_response(id_range: 1..50), headers: {"X-Next-Page": 2})

      stub_request(:get, "https://gitlab.com/api/v4/projects")
        .with(query: {membership: true, per_page: 50, page: 2})
        .to_return_json(body: fake_response(id_range: 51..71), headers: {"X-Next-Page": nil})
    end

    it "returns the transformed list of enabled apps" do
      result = described_class.new(access_token).list_projects(GitlabIntegration::REPOS_TRANSFORMATIONS)

      expect(result.count).to eq(71)
    end
  end

  context "when there are more than 200 results" do
    before do
      stub_request(:get, "https://gitlab.com/api/v4/projects")
        .with(query: {membership: true, per_page: 50})
        .to_return_json(body: fake_response(id_range: 1..50), headers: {"X-Next-Page": 2})

      stub_request(:get, "https://gitlab.com/api/v4/projects")
        .with(query: {membership: true, per_page: 50, page: 2})
        .to_return_json(body: fake_response(id_range: 51..100), headers: {"X-Next-Page": 3})

      stub_request(:get, "https://gitlab.com/api/v4/projects")
        .with(query: {membership: true, per_page: 50, page: 3})
        .to_return_json(body: fake_response(id_range: 101..150), headers: {"X-Next-Page": 4})

      stub_request(:get, "https://gitlab.com/api/v4/projects")
        .with(query: {membership: true, per_page: 50, page: 4})
        .to_return_json(body: fake_response(id_range: 151..200), headers: {"X-Next-Page": 5})

      fifth_page_stub
    end

    let(:fifth_page_stub) do
      stub_request(:get, "https://gitlab.com/api/v4/projects")
        .with(query: {membership: true, per_page: 50, page: 5})
        .to_return_json(body: fake_response(id_range: 201..250), headers: {"X-Next-Page": nil})
    end

    it "stops after fetching 200 results" do
      result = described_class.new(access_token).list_projects(GitlabIntegration::REPOS_TRANSFORMATIONS)

      expect(result.count).to eq(200)
      expect(fifth_page_stub).not_to have_been_requested
    end
  end
end

def fake_response(id_range:)
  id_range.map do |fake_id|
    project_template(fake_id)
  end
end

def project_template(fake_id)
  {
    id: fake_id,
    description: nil,
    name: "Diaspora Client #{fake_id}",
    name_with_namespace: "Diaspora / Diaspora Client #{fake_id}",
    path: "diaspora-client-#{fake_id}",
    path_with_namespace: "diaspora/diaspora-client-#{fake_id}",
    created_at: "2013-09-30T13:46:02Z",
    default_branch: "main",
    tag_list: [
      "example",
      "disapora client"
    ],
    topics: [
      "example",
      "disapora client"
    ],
    ssh_url_to_repo: "git@gitlab.example.com:diaspora/diaspora-client-#{fake_id}.git",
    http_url_to_repo: "https://gitlab.example.com/diaspora/diaspora-client-#{fake_id}.git",
    web_url: "https://gitlab.example.com/diaspora/diaspora-client-#{fake_id}",
    readme_url: "https://gitlab.example.com/diaspora/diaspora-client-#{fake_id}/blob/master/README.md",
    avatar_url: "https://gitlab.example.com/uploads/project/avatar/4/uploads/avatar.png",
    forks_count: 0,
    star_count: 0,
    last_activity_at: "2013-09-30T13:46:02Z",
    namespace: {
      id: 2,
      name: "Diaspora",
      path: "diaspora",
      kind: "group",
      full_path: "diaspora",
      parent_id: nil,
      avatar_url: nil,
      web_url: "https://gitlab.example.com/diaspora"
    }
  }
end

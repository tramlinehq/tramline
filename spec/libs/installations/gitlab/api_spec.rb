require "rails_helper"
require "webmock/rspec"

describe Installations::Gitlab::Api, type: :integration do
  let(:access_token) { "glpat_" + SecureRandom.base58(32) }

  describe "#list_projects" do
    let(:payload_first_page) { JSON.parse(File.read("spec/fixtures/gitlab/projects.json")) }
    let(:payload_second_page) { JSON.parse(File.read("spec/fixtures/gitlab/projects-page-2.json")) }

    before do
      stub_request(:get, "https://gitlab.com/api/v4/projects")
        .with(query: {membership: true})
        .to_return_json(body: payload_first_page, headers: {"X-Next-Page": 2})

      stub_request(:get, "https://gitlab.com/api/v4/projects")
        .with(query: {membership: true, page: 2})
        .to_return_json(body: payload_second_page, headers: {"X-Next-Page": nil})
    end

    it "returns the transformed list of enabled apps" do
      result = described_class.new(access_token).list_projects(GitlabIntegration::REPOS_TRANSFORMATIONS)

      expect(result.count).to eq(29)
    end
  end
end

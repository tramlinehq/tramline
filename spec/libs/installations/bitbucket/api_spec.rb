require "rails_helper"
require "webmock/rspec"

describe Installations::Bitbucket::Api, type: :integration do
  let(:access_token) { Faker::String.random(length: 8) }
  let(:repo_slug) { "tramline/ueno" }
  let(:url) { "https://example.com" }

  describe "#create_repo_webhook!" do
    it "creates a webhook given a repo" do
      response = JSON.parse(File.read("spec/fixtures/bitbucket/webhook.json"))

      allow_any_instance_of(described_class).to receive(:execute).and_return(response)

      result = described_class
        .new(access_token)
        .create_repo_webhook!(repo_slug, url, BitbucketIntegration::WEBHOOK_TRANSFORMATIONS)

      expect(result).to eq({
        "events" => %w[pullrequest:created pullrequest:fulfilled repo:push pullrequest:rejected pullrequest:updated],
        "id" => "{cffc8461-e355-4ab2-9eb9-bb2e800240dc}",
        "url" => "https://example.com"
      })
    end
  end

  describe "#create_branch!" do
    let(:head_ref_sha) { "b3265vwg6gus76" }
    let(:new_branch_name) { "new-branch" }
    let(:source_tag_name) { "v1.2.3" }
    let(:source_branch_name) { "main" }

    it "creates a branch given a name" do
      response = {"target" => {"hash" => head_ref_sha, "type" => "branch"}}
      get_branch_url = described_class::REPO_BRANCH_URL.expand(repo_slug:, branch_name: source_branch_name).to_s
      create_branch_url = described_class::REPO_BRANCHES_URL.expand(repo_slug:).to_s
      get_branch_request = stub_request(:get, get_branch_url).to_return_json(body: response)
      create_branch_request = stub_request(:post, create_branch_url).to_return_json(body: {})

      described_class
        .new(access_token)
        .create_branch!(repo_slug, source_branch_name, new_branch_name)

      expect(get_branch_request.with(headers: {"Authorization" => "Bearer #{access_token}"})).to have_been_made
      expect(
        create_branch_request
          .with(headers: {"Authorization" => "Bearer #{access_token}"})
          .with(body: {name: new_branch_name, target: {hash: head_ref_sha}}.to_json)
      ).to have_been_made
    end

    it "creates a branch given a tag" do
      response = {"target" => {"hash" => head_ref_sha, "type" => "tag"}}
      get_tag_url = described_class::REPO_TAG_URL.expand(repo_slug:, tag_name: source_tag_name).to_s
      create_branch_url = described_class::REPO_BRANCHES_URL.expand(repo_slug:).to_s
      get_tag_request = stub_request(:get, get_tag_url).to_return_json(body: response)
      create_branch_request = stub_request(:post, create_branch_url).to_return_json(body: {})

      described_class
        .new(access_token)
        .create_branch!(repo_slug, source_tag_name, new_branch_name, source_type: :tag)

      expect(get_tag_request.with(headers: {"Authorization" => "Bearer #{access_token}"})).to have_been_made
      expect(
        create_branch_request
          .with(headers: {"Authorization" => "Bearer #{access_token}"})
          .with(body: {name: new_branch_name, target: {hash: head_ref_sha}}.to_json)
      ).to have_been_made
    end

    it "creates a branch given a commit" do
      create_branch_url = described_class::REPO_BRANCHES_URL.expand(repo_slug:).to_s
      create_branch_request = stub_request(:post, create_branch_url).to_return_json(body: {})

      described_class
        .new(access_token)
        .create_branch!(repo_slug, head_ref_sha, new_branch_name, source_type: :commit)

      expect(
        create_branch_request
          .with(headers: {"Authorization" => "Bearer #{access_token}"})
          .with(body: {name: new_branch_name, target: {hash: head_ref_sha}}.to_json)
      ).to have_been_made
    end
  end
end

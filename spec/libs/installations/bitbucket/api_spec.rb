require "rails_helper"

describe Installations::Bitbucket::Api, type: :integration do
  let(:access_token) { Faker::String.random(length: 8) }

  describe "#create_repo_webhook!" do
    it "creates a webhook given a repo" do
      workspace = "tramline"
      repo_slug = "ueno"
      url = "https://example.com"
      response = {
        "type" => "webhook_subscription",
        "uuid" => "{cffc8461-e355-4ab2-9eb9-bb2e800240dc}",
        "description" => "Tramline",
        "url" => "https://example.com",
        "active" => true,
        "skip_cert_verification" => false,
        "events" => %w[pullrequest:created pullrequest:fulfilled repo:push pullrequest:rejected pullrequest:updated],
        "created_at" => "2024-09-04T13:40:59.613181841Z",
        "subject" =>
          {"type" => "repository",
           "full_name" => "tramline/ueno",
           "links" =>
              {"self" => {"href" => "https://api.bitbucket.org/2.0/repositories/tramline/ueno"},
               "html" => {"href" => "https://bitbucket.org/tramline/ueno"},
               "avatar" => {"href" => "https://bytebucket.org/ravatar/%7Babd86e4d-4ad5-4d31-b727-9ccf26604d37%7D?ts=3627142"}},
           "name" => "ueno",
           "uuid" => "{abd86e4d-4ad5-4d31-b727-9ccf26604d37}"},
        "links" => {"self" => {"href" => "https://api.bitbucket.org/2.0/repositories/tramline/ueno/hooks/%7Bcffc8461-e355-4ab2-9eb9-bb2e800240dc%7D"}},
        "source" => nil,
        "read_only" => false,
        "history_enabled" => false,
        "secret_set" => false
      }

      allow_any_instance_of(described_class).to receive(:execute).and_return(response)

      result = described_class.new(access_token, workspace).create_repo_webhook!(repo_slug, url, BitbucketIntegration::WEBHOOK_TRANSFORMATIONS)
      expect(result).to eq({
        "events" => %w[pullrequest:created pullrequest:fulfilled repo:push pullrequest:rejected pullrequest:updated],
        "id" => "{cffc8461-e355-4ab2-9eb9-bb2e800240dc}",
        "url" => "https://example.com"
      })
    end
  end
end


require "rails_helper"

describe Installations::Bitrise::Api, type: :integration do
  let(:access_token) { Faker::String.random(length: 8) }

  describe "#list_apps" do
    let(:payload) { JSON.parse(File.read("spec/fixtures/bitrise/apps.json")) }

    it "returns the transformed list of enabled apps" do
      allow_any_instance_of(described_class).to receive(:execute).with(:get,
        "https://api.bitrise.io/v0.1/apps",
        {}).and_return(payload)
      result = described_class.new(access_token).list_apps(BitriseIntegration::LIST_APPS_TRANSFORMATIONS)

      expected_apps = [
        {
          id: "d3853d44004b2080",
          name: "ueno",
          provider: "gitlab",
          repo_url: "git@gitlab.com:tramline/ueno.git",
          avatar_url: nil
        },
        {
          id: "e92eb64365bcdd8f",
          name: "ueno",
          provider: "github",
          repo_url: "https://github.com/tramlinehq/ueno.git",
          avatar_url: nil
        }
      ]
      expect(result).to contain_exactly(*expected_apps)
    end
  end

  describe "#list_workflows" do
    let(:payload) { JSON.parse(File.read("spec/fixtures/bitrise/workflows.json")) }
    let(:app_slug) { Faker::Lorem.characters(number: 8) }

    it "returns the transformed list of workflows" do
      allow_any_instance_of(described_class).to receive(:execute).with(:get,
        "https://api.bitrise.io/v0.1/apps/#{app_slug}/build-workflows",
        {}).and_return(payload)
      result = described_class.new(access_token).list_workflows(app_slug, BitriseIntegration::LIST_WORKFLOWS_TRANSFORMATIONS)

      puts result.first.class
      expected = [
        {
          id: "debug",
          name: "debug"
        },
        {
          id: "release",
          name: "release"
        },
        {
          id: "deploy",
          name: "deploy"
        },
        {
          id: "primary",
          name: "primary"
        }
      ]
      expect(result).to contain_exactly(*expected)
    end
  end
end

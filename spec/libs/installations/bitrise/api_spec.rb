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

  describe "#run_workflow!" do
    it "triggers the workflow and returns the transformed workflow run" do
      payload = JSON.parse(File.read("spec/fixtures/bitrise/workflow.json"))
      app_slug = Faker::Lorem.characters(number: 8)
      workflow_id = Faker::Lorem.characters(number: 8)
      branch = Faker::Lorem.characters(number: 8)
      inputs = {
        version_code: Faker::Number.number(digits: 4),
        build_version: Faker::Lorem.characters(number: 8)
      }
      commit_hash = Faker::Crypto.sha1
      params = {
        json: {
          build_params: {
            branch: branch,
            commit_hash: commit_hash,
            workflow_id: workflow_id,
            environments: [
              {mapped_to: "BUILD_VERSION", value: inputs[:build_version]},
              {mapped_to: "BUILD_NUMBER", value: inputs[:version_code]}
            ]
          },

          hook_info: {
            type: "bitrise"
          }
        }
      }

      allow_any_instance_of(described_class).to receive(:execute).with(:post,
        "https://api.bitrise.io/v0.1/apps/#{app_slug}/builds",
        params).and_return(payload)
      result = described_class.new(access_token).run_workflow!(app_slug, workflow_id, branch, inputs, commit_hash,
        BitriseIntegration::RUN_WORKFLOW_TRANSFORMATIONS)

      expected = {
        ci_ref: "d40e1f6c-e3a0-4c37-bbb0-1fa22ecdc8c5",
        ci_link: "https://app.bitrise.io/build/d40e1f6c-e3a0-4c37-bbb0-1fa22ecdc8c5"
      }
      expect(result).to eq(expected.with_indifferent_access)
    end
  end
end

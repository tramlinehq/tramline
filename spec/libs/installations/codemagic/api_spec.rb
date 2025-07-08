require "rails_helper"

describe Installations::Codemagic::Api, type: :integration do
  let(:access_token) { Faker::String.random(length: 8) }

  describe "#list_apps" do
    let(:payload) { JSON.parse(File.read("spec/fixtures/codemagic/apps.json")) }

    it "returns the transformed list of apps" do
      url = "https://api.codemagic.io/apps"
      allow_any_instance_of(described_class).to receive(:execute).with(:get, url, {}).and_return(payload)
      result = described_class.new(access_token).list_apps(CodemagicIntegration::APPS_TRANSFORMATIONS)

      expected_apps = [
        {
          id: "5d85eaa0e941e00019e81bc2",
          name: "flutter_counter",
          provider: "https://github.com/tramlinehq/flutter_counter.git",
          repo_url: "https://github.com/tramlinehq/flutter_counter.git"
        },
        {
          id: "6f95fbb1f052f11129f92cd3",
          name: "android_sample",
          provider: "https://github.com/tramlinehq/android_sample.git",
          repo_url: "https://github.com/tramlinehq/android_sample.git"
        }
      ]
      expect(result).to match_array(expected_apps)
    end
  end

  describe "#list_workflows" do
    let(:app_id) { Faker::Lorem.characters(number: 8) }

    it "returns the transformed list of workflows" do
      result = described_class.new(access_token).list_workflows(app_id, CodemagicIntegration::WORKFLOWS_TRANSFORMATIONS)

      expected = [
        {
          id: "default-workflow",
          name: "default-workflow"
        },
        {
          id: "release",
          name: "release"
        },
        {
          id: "debug",
          name: "debug"
        },
        {
          id: "staging",
          name: "staging"
        }
      ]
      expect(result).to match_array(expected)
    end
  end

  describe "#run_workflow!" do
    it "triggers the workflow and returns the transformed workflow run" do
      build_payload = JSON.parse(File.read("spec/fixtures/codemagic/build.json"))
      trigger_payload = {"buildId" => "5fabc6414c483700143f4f92"}
      app_id = Faker::Lorem.characters(number: 8)
      workflow_id = Faker::Lorem.characters(number: 8)
      branch = Faker::Lorem.characters(number: 8)
      inputs = {
        version_code: Faker::Number.number(digits: 4),
        build_version: Faker::Lorem.characters(number: 8),
        build_notes: Faker::Lorem.characters(number: 10),
        parameters: {}
      }
      commit_hash = Faker::Crypto.sha1

      trigger_url = "https://api.codemagic.io/builds"
      get_build_url = "https://api.codemagic.io/builds/5fabc6414c483700143f4f92"

      # Mock the trigger build call
      allow_any_instance_of(described_class).to receive(:execute).with(:post, trigger_url, anything).and_return(trigger_payload)
      # Mock the get build details call
      allow_any_instance_of(described_class).to receive(:execute).with(:get, get_build_url, {}).and_return({"build" => build_payload})

      result = described_class.new(access_token).run_workflow!(app_id, workflow_id, branch, inputs, commit_hash, CodemagicIntegration::WORKFLOW_RUN_TRANSFORMATIONS)

      expected = {
        ci_ref: "5fabc6414c483700143f4f92",
        ci_link: "https://codemagic.io/app/#{app_id}/build/5fabc6414c483700143f4f92",
        number: 42,
        unique_number: 42
      }
      expect(result).to match(expected)
    end
  end
end

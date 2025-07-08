module Installations
  require "down/http"

  class Codemagic::Api
    include Vaultable
    using RefinedString

    attr_reader :access_token

    # CodeMagic REST API endpoints
    # Reference: https://docs.codemagic.io/rest-api/overview/
    # Applications API: https://docs.codemagic.io/rest-api/applications/
    # Builds API: https://docs.codemagic.io/rest-api/builds/
    # Artifacts API: https://docs.codemagic.io/rest-api/artifacts/
    LIST_APPS_URL = "https://api.codemagic.io/apps"
    LIST_WORKFLOWS_URL = Addressable::Template.new("https://api.codemagic.io/apps/{app_id}/workflows")
    TRIGGER_BUILD_URL = "https://api.codemagic.io/builds"
    CANCEL_BUILD_URL = Addressable::Template.new("https://api.codemagic.io/builds/{build_id}/cancel")
    GET_BUILD_URL = Addressable::Template.new("https://api.codemagic.io/builds/{build_id}")
    LIST_BUILDS_URL = "https://api.codemagic.io/builds"
    GET_ARTIFACTS_URL = Addressable::Template.new("https://api.codemagic.io/artifacts/{build_id}")

    VALID_ARTIFACT_TYPES = %w[apk ipa app].freeze

    def initialize(access_token)
      @access_token = access_token
    end

    class << self
      def filter_by_relevant_type(artifacts)
        artifacts.select { |artifact| VALID_ARTIFACT_TYPES.include? artifact["type"] }
      end

      def find_biggest(artifacts)
        artifacts.max_by do |artifact|
          file_size = artifact["size"]
          case file_size.class
          when Integer
            file_size
          when String
            file_size.safe_integer
          end
        end
      end

      def filter_by_name(artifacts, name_pattern)
        return artifacts if name_pattern.blank?
        artifacts.filter { |artifact| artifact.fetch("name")&.downcase&.include? name_pattern }.presence || artifacts
      end
    end

    # Get list of applications
    # Reference: https://docs.codemagic.io/rest-api/applications/
    def list_apps(transforms)
      execute(:get, LIST_APPS_URL, {})
        .then { |response| response&.fetch("applications", nil) }
        .then { |responses| Installations::Response::Keys.transform(responses, transforms) }
    end

    # Get workflows for an application (Note: CodeMagic workflows are defined in codemagic.yaml)
    # Reference: https://docs.codemagic.io/rest-api/applications/
    # CodeMagic workflows are defined in codemagic.yaml and not accessible via API
    # We provide a default set of common workflow names
    def list_workflows(app_id, transforms)
      default_workflows = [
        {id: "default-workflow", name: "default-workflow"},
        {id: "release", name: "release"},
        {id: "debug", name: "debug"},
        {id: "staging", name: "staging"}
      ]
      Installations::Response::Keys.transform(default_workflows, transforms)
    end

    # Start a new build
    # Reference: https://docs.codemagic.io/rest-api/builds/
    def run_workflow!(app_id, workflow_id, branch, inputs, commit_hash, transforms)
      params = {
        json: {
          appId: app_id,
          workflowId: workflow_id,
          branch: branch,
          environment: {
            variables: {
              CM_BUILD_VERSION: inputs[:build_version],
              CM_VERSION_CODE: inputs[:version_code],
              CM_BUILD_NOTES: inputs[:build_notes] || ""
            }.merge(inputs[:parameters] || {}).compact
          }
        }.compact
      }

      execute(:post, TRIGGER_BUILD_URL, params)
        .tap { |response| raise Installations::Error.new("Could not trigger the workflow", reason: :workflow_trigger_failed) if response.blank? }
        .then { |response|
          # Get the full build details to construct the proper response
          build_id = response["buildId"]
          build_details = get_workflow_run(build_id)
          build_details["appId"] = app_id  # Ensure appId is present for URL construction
          Installations::Response::Keys.transform([build_details], transforms)
        }
        .first
        .tap { |result|
          # Construct the ci_link URL after transformation
          if result[:ci_link] && result[:ci_ref]
            result[:ci_link] = "https://codemagic.io/app/#{app_id}/build/#{result[:ci_ref]}"
          end
        }
    end

    # Cancel a build
    # Reference: https://docs.codemagic.io/rest-api/builds/
    def cancel_workflow!(build_id)
      execute(:post, CANCEL_BUILD_URL.expand(build_id:).to_s, {})
    end

    # Get build status
    # Reference: https://docs.codemagic.io/rest-api/builds/
    def get_workflow_run(build_id)
      execute(:get, GET_BUILD_URL.expand(build_id:).to_s, {})
        &.fetch("build", nil)
        &.with_indifferent_access
    end

    # Get build artifacts
    # Reference: https://docs.codemagic.io/rest-api/artifacts/
    def artifacts(build_id)
      execute(:get, GET_ARTIFACTS_URL.expand(build_id:).to_s, {})
        .then { |response| response&.fetch("artifacts", nil) }
    end

    def artifact(artifact_url, transforms)
      execute(:get, artifact_url, {})
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    def download_artifact(download_url)
      Down::Http.download(download_url, headers: {"x-auth-token" => access_token}, follow: {max_hops: 1})
    end

    private

    def execute(verb, url, params)
      response = HTTP.headers("x-auth-token" => access_token.to_s, "Content-Type" => "application/json").public_send(verb, url, params)
      body = JSON.parse(response.body.to_s)
      body unless error?(response.status)
    end

    def error?(code)
      code.between?(400, 499)
    end
  end
end

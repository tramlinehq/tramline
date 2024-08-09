module Installations
  require "down/http"

  class Bitrise::Api
    include Vaultable
    using RefinedString

    attr_reader :access_token

    LIST_ORGS_URL = "https://api.bitrise.io/v0.1/organizations"
    LIST_APPS_URL = "https://api.bitrise.io/v0.1/apps"
    LIST_WORKFLOWS_URL = Addressable::Template.new("https://api.bitrise.io/v0.1/apps/{app_slug}/build-workflows")
    TRIGGER_WORKFLOW_URL = Addressable::Template.new("https://api.bitrise.io/v0.1/apps/{app_slug}/builds")
    CANCEL_WORKFLOW_URL = Addressable::Template.new("https://api.bitrise.io/v0.1/apps/{app_slug}/builds/{build_slug}/abort")
    WORKFLOW_RUN_URL = Addressable::Template.new("https://api.bitrise.io/v0.1/apps/{app_slug}/builds/{build_slug}")
    WORKFLOW_RUN_ARTIFACTS_URL = Addressable::Template.new("https://api.bitrise.io/v0.1/apps/{app_slug}/builds/{build_slug}/artifacts")
    WORKFLOW_RUN_ARTIFACT_URL = Addressable::Template.new("https://api.bitrise.io/v0.1/apps/{app_slug}/builds/{build_slug}/artifacts/{artifact_slug}")

    VALID_ARTIFACT_TYPES = %w[android-apk ios-ipa].freeze

    def initialize(access_token)
      @access_token = access_token
    end

    class << self
      def artifact_url(app_slug, build_slug, artifact)
        return if artifact.blank?
        WORKFLOW_RUN_ARTIFACT_URL.expand(app_slug:, build_slug:, artifact_slug: artifact["slug"]).to_s
      end

      def filter_by_relevant_type(artifacts)
        artifacts.select { |artifact| VALID_ARTIFACT_TYPES.include? artifact["artifact_type"] }
      end

      def find_biggest(artifacts)
        artifacts.max_by { |artifact| artifact.dig("artifact_meta", "file_size_bytes")&.safe_float }
      end

      def filter_by_name(artifacts, name_pattern)
        return artifacts if name_pattern.blank?
        artifacts.filter { |artifact| artifact.fetch("title")&.downcase&.include? name_pattern }.presence || artifacts
      end
    end

    def list_organizations(transforms)
      execute(:get, LIST_ORGS_URL, {})
        .then { |response| response&.fetch("data", nil) }
        .then { |responses| Installations::Response::Keys.transform(responses, transforms) }
    end

    def list_apps(transforms)
      execute(:get, LIST_APPS_URL, {})
        .then { |response| response&.fetch("data", nil) }
        .then { |apps| apps&.reject { |app| app.to_h["is_disabled"] } }
        .then { |responses| Installations::Response::Keys.transform(responses, transforms) }
    end

    def list_workflows(app_slug, transforms)
      execute(:get, LIST_WORKFLOWS_URL.expand(app_slug:).to_s, {})
        &.fetch("data", [])
        &.map { |workflow| {id: workflow, name: workflow} }
        .then { |workflows| Installations::Response::Keys.transform(workflows, transforms) }
    end

    def run_workflow!(app_slug, workflow_id, branch, inputs, commit_hash, transforms)
      params = {
        json: {
          build_params: {
            branch: branch,
            commit_hash: commit_hash,
            workflow_id: workflow_id,
            environments: [
              {mapped_to: "versionName", value: inputs[:build_version]},
              {mapped_to: "versionCode", value: inputs[:version_code]},
              {mapped_to: "buildNotes", value: inputs[:build_notes] || ""}
            ]
          },

          hook_info: {
            type: "bitrise"
          }
        }
      }

      execute(:post, TRIGGER_WORKFLOW_URL.expand(app_slug:).to_s, params)
        .tap { |response| raise Installations::Errors::WorkflowTriggerFailed if response.blank? }
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    def cancel_workflow!(app_slug, build_slug)
      params = {
        json: {
          abort_reason: "build for a newer commit has started",
          abort_with_success: true,
          skip_notifications: true
        }
      }
      execute(:post, CANCEL_WORKFLOW_URL.expand(app_slug:, build_slug:).to_s, params)
    end

    def get_workflow_run(app_slug, build_slug)
      execute(:get, WORKFLOW_RUN_URL.expand(app_slug:, build_slug:).to_s, {})
        &.fetch("data", nil)
        &.with_indifferent_access
    end

    def artifacts(app_slug, build_slug)
      execute(:get, WORKFLOW_RUN_ARTIFACTS_URL.expand(app_slug:, build_slug:).to_s, {})
        .then { |response| response&.fetch("data", nil) }
    end

    def artifact_io_stream(artifact_url)
      execute(:get, artifact_url, {})
        .then { |response| response.dig("data", "expiring_download_url") }
        .then { |download_url| download_artifact(download_url) }
    end

    def artifact(artifact_url, transforms)
      execute(:get, artifact_url, {})
        .then { |response| Installations::Response::Keys.transform([response["data"]], transforms) }
        .first
    end

    def download_artifact(download_url)
      # FIXME: return an IO stream instead of a TempFile
      # See issue: https://github.com/janko/down/issues/70
      Down::Http.download(download_url, headers: {"Authorization" => access_token}, follow: {max_hops: 1})
    end

    private

    def execute(verb, url, params)
      response = HTTP.auth(access_token.to_s).public_send(verb, url, params)
      body = JSON.parse(response.body.to_s)
      body unless error?(response.status)
    end

    def error?(code)
      code.between?(400, 499)
    end
  end
end

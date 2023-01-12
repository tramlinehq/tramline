module Installations
  require "down/http"

  class Bitrise::Api
    include Vaultable
    using RefinedString

    attr_reader :access_token

    LIST_APPS_URL = "https://api.bitrise.io/v0.1/apps"
    LIST_WORKFLOWS_URL = Addressable::Template.new("https://api.bitrise.io/v0.1/apps/{app_slug}/build-workflows")
    TRIGGER_WORKFLOW_URL = Addressable::Template.new("https://api.bitrise.io/v0.1/apps/{app_slug}/builds")
    WORKFLOW_RUN_URL = Addressable::Template.new("https://api.bitrise.io/v0.1/apps/{app_slug}/builds/{build_slug}")
    WORKFLOW_RUN_ARTIFACTS_URL = Addressable::Template.new("https://api.bitrise.io/v0.1/apps/{app_slug}/builds/{build_slug}/artifacts")
    WORKFLOW_RUN_ARTIFACT_URL = Addressable::Template.new("https://api.bitrise.io/v0.1/apps/{app_slug}/builds/{build_slug}/artifacts/{artifact_slug}")

    def initialize(access_token)
      @access_token = access_token
    end

    class << self
      def artifact_url(app_slug, build_slug, artifact)
        WORKFLOW_RUN_ARTIFACT_URL.expand(app_slug:, build_slug:, artifact_slug: artifact["slug"]).to_s
      end

      def filter_android(artifacts)
        artifacts.select { |artifact| artifact["artifact_type"] == "android-apk" }
      end

      def find_biggest(artifacts)
        artifacts.max_by { |artifact| artifact.dig("artifact_meta", "file_size_bytes")&.safe_float }
      end
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

    def run_workflow!(app_slug, workflow_id, branch, inputs, commit_hash)
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

      execute(:post, TRIGGER_WORKFLOW_URL.expand(app_slug:).to_s, params)
        .tap { |response| raise Installations::Errors::WorkflowTriggerFailed if response.blank? }
        .then { |build| build.slice("build_slug", "build_url") }
        .then { |response| Installations::Response::Keys.normalize([response], :workflow_runs) }
        .first
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

    private

    def download_artifact(download_url)
      # FIXME: return an IO stream instead of a TempFile
      # See issue: https://github.com/janko/down/issues/70
      Down::Http.download(download_url, headers: {"Authorization" => access_token}, follow: {max_hops: 1})
    end

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

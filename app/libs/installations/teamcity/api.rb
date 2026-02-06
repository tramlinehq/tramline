module Installations
  require "down/http"

  class Teamcity::Api
    include Vaultable
    using RefinedString

    attr_reader :server_url, :access_token, :cloudflare_credentials

    def initialize(server_url, access_token, cloudflare_credentials: nil)
      @server_url = server_url.chomp("/")
      @access_token = access_token
      @cloudflare_credentials = cloudflare_credentials
    end

    def cloudflare_enabled?
      cloudflare_credentials.present?
    end

    class << self
      def filter_by_name(artifacts, name_pattern)
        return artifacts if name_pattern.blank?
        artifacts.filter { |a| a[:name]&.downcase&.include?(name_pattern) }.presence || artifacts
      end

      def find_biggest(artifacts)
        artifacts.max_by { |a| a[:size_in_bytes].to_i }
      end
    end

    def server_version
      execute(:get, "/app/rest/server")
        .then { |response| response&.dig("version") }
    end

    def list_projects(transforms)
      execute(:get, "/app/rest/projects")
        .then { |response| response&.dig("project") || [] }
        .then { |projects| projects.reject { |p| p["id"] == "_Root" } }
        .then { |projects| Installations::Response::Keys.transform(projects, transforms) }
    end

    def list_build_configurations(project_id, transforms)
      execute(:get, "/app/rest/projects/id:#{sanitize_locator_value(project_id)}/buildTypes")
        .then { |response| response&.dig("buildType") || [] }
        .then { |configs| Installations::Response::Keys.transform(configs, transforms) }
    end

    def trigger_build(build_type_id, branch, inputs, commit_hash, transforms)
      body = {
        buildType: { id: build_type_id },
        branchName: branch,
        properties: {
          property: build_properties(inputs, commit_hash)
        }
      }

      body[:lastChanges] = { change: [{ locator: "version:#{commit_hash}" }] } if commit_hash.present?

      execute(:post, "/app/rest/buildQueue", json: body)
        .tap { |response| raise Installations::Error.new("Could not trigger the build", reason: :workflow_trigger_failed) if response.blank? }
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    def cancel_build(build_id)
      build = get_build(build_id)
      state = build&.dig("state")&.downcase

      if state == "queued"
        # Queued builds must be removed from the queue
        execute(:post, "/app/rest/buildQueue/id:#{build_id}", json: {
          comment: "Cancelled by Tramline",
          readdIntoQueue: false
        })
      else
        # Running builds are cancelled via the builds endpoint
        execute(:post, "/app/rest/builds/id:#{build_id}", json: {
          comment: "Cancelled by Tramline - build for a newer commit has started",
          readdIntoQueue: false
        })
      end
    end

    def get_build(build_id)
      execute(:get, "/app/rest/builds/id:#{build_id}")
        &.with_indifferent_access
    end

    def find_build(build_type_id, branch, commit_sha, transforms)
      encoded_branch = sanitize_locator_value(branch)
      locator = "buildType:(id:#{build_type_id}),branch:(name:#{encoded_branch}),revision:#{commit_sha},count:1"

      execute(:get, "/app/rest/builds", params: {locator:})
        .then { |response| response&.dig("build") || [] }
        .then { |builds| Installations::Response::Keys.transform(builds, transforms) }
        .first
        .then { |build| build&.presence || raise(Installations::Error.new("Could not find the build", reason: :workflow_run_not_found)) }
    end

    def list_artifacts(build_id)
      execute(:get, "/app/rest/builds/id:#{build_id}/artifacts")
        .then { |response| response&.dig("file") || [] }
        .then { |files| files.select { |f| artifact_file?(f) } }
    end

    def get_artifact_metadata(build_id, artifact_path, transforms)
      execute(:get, "/app/rest/builds/id:#{build_id}/artifacts/metadata/#{artifact_path}")
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    def download_artifact(build_id, artifact_path)
      url = "#{server_url}/app/rest/builds/id:#{build_id}/artifacts/content/#{URI.encode_www_form_component(artifact_path)}"
      Down::Http.download(url, headers: auth_headers, follow: {max_hops: 1})
    end

    private

    def build_properties(inputs, commit_hash)
      properties = []

      properties << { name: "env.VERSION_NAME", value: inputs[:build_version] } if inputs[:build_version]
      properties << { name: "env.VERSION_CODE", value: inputs[:version_code].to_s } if inputs[:version_code]
      properties << { name: "env.BUILD_NOTES", value: inputs[:build_notes] } if inputs[:build_notes]
      properties << { name: "env.COMMIT_REF", value: commit_hash } if commit_hash

      inputs[:parameters]&.each do |name, value|
        properties << { name: name, value: value.to_s }
      end

      properties
    end

    # TeamCity locator values with special chars (parentheses, commas, colons) must be escaped
    def sanitize_locator_value(value)
      value.to_s.gsub(/([(),])/) { |char| "\\#{char}" }
    end

    def artifact_file?(file)
      name = file["name"]&.downcase
      return false unless name
      name.end_with?(".apk", ".aab", ".ipa", ".app.zip")
    end

    def execute(verb, path, params: {}, json: nil)
      url = "#{server_url}#{path}"

      request = HTTP.auth("Bearer #{access_token}")
                    .headers(default_headers)
                    .timeout(connect: 10, read: 30)

      response = if json
        request.public_send(verb, url, json: json, params: params)
      else
        request.public_send(verb, url, params: params)
      end

      raise Installations::Error::ServerError if response.status.server_error?
      return nil if response.status.client_error?

      JSON.parse(response.body.to_s)
    rescue JSON::ParserError
      nil
    end

    def default_headers
      headers = {
        "Accept" => "application/json",
        "Content-Type" => "application/json"
      }

      # Add Cloudflare Zero Trust headers if configured
      if cloudflare_enabled?
        headers["CF-Access-Client-Id"] = cloudflare_credentials[:client_id]
        headers["CF-Access-Client-Secret"] = cloudflare_credentials[:client_secret]
      end

      headers
    end

    def auth_headers
      headers = { "Authorization" => "Bearer #{access_token}" }

      # Add Cloudflare Zero Trust headers if configured
      if cloudflare_enabled?
        headers["CF-Access-Client-Id"] = cloudflare_credentials[:client_id]
        headers["CF-Access-Client-Secret"] = cloudflare_credentials[:client_secret]
      end

      headers
    end

  end
end

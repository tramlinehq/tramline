module Installations
  class Bitbucket::Api
    require "down/http"
    require "yaml"
    using RefinedString
    include Vaultable
    attr_reader :oauth_access_token

    BASE_URL = "https://api.bitbucket.org/2.0"
    USER_INFO_URL = "#{BASE_URL}/user"
    WORKSPACES_URL = "#{BASE_URL}/workspaces"
    REPOS_URL = Addressable::Template.new "#{BASE_URL}/repositories/{workspace}"
    REPO_HOOKS_URL = Addressable::Template.new "#{BASE_URL}/repositories/{repo_slug}/hooks"
    REPO_HOOK_URL = Addressable::Template.new "#{BASE_URL}/repositories/{repo_slug}/hooks/{hook_id}"
    REPO_BRANCHES_URL = Addressable::Template.new "#{BASE_URL}/repositories/{repo_slug}/refs/branches"
    REPO_BRANCH_URL = Addressable::Template.new "#{BASE_URL}/repositories/{repo_slug}/refs/branches/{branch_name}"
    REPO_TAGS_URL = Addressable::Template.new "#{BASE_URL}/repositories/{repo_slug}/refs/tags"
    REPO_TAG_URL = Addressable::Template.new "#{BASE_URL}/repositories/{repo_slug}/refs/tags/{tag_name}"
    DIFFSTAT_URL = Addressable::Template.new "#{BASE_URL}/repositories/{repo_slug}/diffstat/{to_sha}..{from_sha}"
    PRS_URL = Addressable::Template.new "#{BASE_URL}/repositories/{repo_slug}/pullrequests"
    PR_URL = Addressable::Template.new "#{BASE_URL}/repositories/{repo_slug}/pullrequests/{pr_number}"
    PR_MERGE_URL = Addressable::Template.new "#{BASE_URL}/repositories/{repo_slug}/pullrequests/{pr_number}/merge"
    REPO_COMMITS_URL = Addressable::Template.new "#{BASE_URL}/repositories/{repo_slug}/commits"
    REPO_COMMIT_URL = Addressable::Template.new "#{BASE_URL}/repositories/{repo_slug}/commit/{sha}"
    GET_COMMIT_URL = Addressable::Template.new "#{BASE_URL}/repositories/{repo_slug}/commit/{commit_sha}"
    PIPELINES_URL = Addressable::Template.new "#{BASE_URL}/repositories/{repo_slug}/pipelines"
    PIPELINE_URL = Addressable::Template.new "#{BASE_URL}/repositories/{repo_slug}/pipelines/{pipeline_id}"
    STOP_PIPELINE_URL = Addressable::Template.new "#{BASE_URL}/repositories/{repo_slug}/pipelines/{pipeline_id}/stopPipeline"
    LIST_FILES_URL = Addressable::Template.new "#{BASE_URL}/repositories/{repo_slug}/downloads"
    GET_FILE_URL = Addressable::Template.new "#{BASE_URL}/repositories/{repo_slug}/downloads/{file_name}"
    PIPELINE_YAML_URL = Addressable::Template.new "#{BASE_URL}/repositories/{repo_slug}/src/{sha}/bitbucket-pipelines.yml"

    WEBHOOK_EVENTS = %w[repo:push pullrequest:created pullrequest:updated pullrequest:fulfilled pullrequest:rejected]

    class << self
      include Vaultable

      OAUTH_ACCESS_TOKEN_URL = "https://bitbucket.org/site/oauth2/access_token"

      def oauth_access_token(code, redirect_uri)
        params = {
          form: {
            grant_type: :authorization_code,
            code:,
            redirect_uri:
          }
        }

        get_oauth_token(params)
      end

      def oauth_refresh_token(refresh_token, redirect_uri)
        params = {
          form: {
            grant_type: :refresh_token,
            redirect_uri:,
            refresh_token:
          }
        }

        get_oauth_token(params)
      end

      def get_oauth_token(params)
        HTTP
          .basic_auth(user: creds.integrations.bitbucket.client_id, pass: creds.integrations.bitbucket.client_secret)
          .post(OAUTH_ACCESS_TOKEN_URL, params)
          .then { |response| response.body.to_s }
          .then { |body| JSON.parse(body) }
          .then { |json| json.slice("access_token", "refresh_token") }
          .then.detect(&:present?)
          .then { |tokens| OpenStruct.new tokens }
      end

      def parse_author_info(commit)
        if (match = /\A(.*)<(.*)>\z/.match(commit[:author_raw]))
          commit[:author_name] = match[1].strip
          commit[:author_email] = match[2].strip
        else
          commit[:author_name] = commit[:author_raw]
          commit[:author_email] = commit[:author_raw]
        end

        commit.delete(:author_raw)
        commit
      end
    end

    def initialize(oauth_access_token)
      @oauth_access_token = oauth_access_token
    end

    def user_info(transforms)
      execute(:get, USER_INFO_URL)
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    def list_workspaces(transforms)
      execute(:get, WORKSPACES_URL)
        .then { |responses| Installations::Response::Keys.transform(responses["values"], transforms) }
    end

    def list_repos(workspace, transforms)
      execute(:get, REPOS_URL.expand(workspace:).to_s)
        .then { |responses| Installations::Response::Keys.transform(responses["values"], transforms) }
    end

    def create_repo_webhook!(repo_slug, url, transforms)
      execute(:post, REPO_HOOKS_URL.expand(repo_slug:).to_s, webhook_params(url))
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    def update_repo_webhook!(repo_slug, hook_id, url, transforms)
      execute(:put, REPO_HOOK_URL.expand(repo_slug:, hook_id:).to_s, webhook_params(url))
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    def find_webhook(repo_slug, hook_id, transforms)
      execute(:get, REPO_HOOK_URL.expand(repo_slug:, hook_id:).to_s)
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    def create_branch!(repo_slug, source_name, new_branch_name, source_type: :branch)
      ref =
        case source_type
        when :commit
          source_name
        when :branch
          get_branch(repo_slug, source_name).dig("target", "hash")
        when :tag
          get_tag(repo_slug, source_name).dig("target", "hash")
        else
          raise ArgumentError, "source can only be a branch, tag or commit"
        end

      params = {
        json: {
          name: new_branch_name,
          target: {hash: ref}
        }
      }

      execute(:post, REPO_BRANCHES_URL.expand(repo_slug:).to_s, params)
    end

    def create_tag!(repo_slug, tag_name, sha)
      params = {
        json: {
          name: tag_name,
          target: {hash: sha}
        }
      }

      execute(:post, REPO_TAGS_URL.expand(repo_slug:).to_s, params)
    end

    def get_branch(repo_slug, branch_name)
      execute(:get, REPO_BRANCH_URL.expand(repo_slug:, branch_name:).to_s)
    end

    def get_tag(repo_slug, tag_name)
      execute(:get, REPO_TAG_URL.expand(repo_slug:, tag_name:).to_s)
    end

    def create_pr!(repo_slug, to, from, title, description, transforms)
      raise Installations::Error.new("Should not create a Pull Request without a diff", reason: :pull_request_without_commits) unless diff?(repo_slug, to, from)

      params = {
        json: {
          title:,
          source: {branch: {name: from}},
          destination: {branch: {name: to}},
          description:
        }
      }

      execute(:post, PRS_URL.expand(repo_slug:).to_s, params)
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    def find_pr(repo_slug, to, from, transforms)
      params = {
        params: {
          q: <<~QUERY
            state="OPEN" AND
            source.branch.name="#{from}" AND
            destination.branch.name="#{to}
          QUERY
        }
      }

      execute(:get, PRS_URL.expand(repo_slug:).to_s, params)
        .then { |response| Installations::Response::Keys.transform(response["values"], transforms) }
        .first
    end

    def get_pr(repo, pr_number, transforms)
      execute(:get, PR_URL.expand(repo_slug: repo, pr_number:).to_s)
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    def merge_pr!(repo_slug, pr_number)
      execute(:post, PR_MERGE_URL.expand(repo_slug:, pr_number:).to_s)
    end

    def commits_between(repo, from_branch, to_branch, transforms)
      params = {
        params: {
          include: to_branch,
          exclude: from_branch
        }
      }

      paginated_execute(:get, REPO_COMMITS_URL.expand(repo_slug: repo).to_s, params)
        .then { |commits| Installations::Response::Keys.transform(commits, transforms) }
        .map { |commit| self.class.parse_author_info(commit) }
    end

    def diff?(repo_slug, from_branch, to_branch, from_type = :branch, to_type = :branch)
      from_sha = get_sha_for_ref(repo_slug, from_branch, from_type)
      to_sha = get_sha_for_ref(repo_slug, to_branch, to_type)

      # This is equivalent to git diff from_sha..to_sha
      execute(:get, DIFFSTAT_URL.expand(repo_slug:, from_sha:, to_sha:).to_s)
        .dig("size")
        .positive?
    end

    def head(repo_slug, branch_name, sha_only: true, commit_transforms: nil)
      raise ArgumentError, "transforms must be supplied when querying head object" if !sha_only && !commit_transforms

      sha = get_branch(repo_slug, branch_name).dig("target", "hash")
      return sha if sha_only
      get_commit(repo_slug, sha, commit_transforms)
    end

    def get_commit(repo_slug, sha, transforms)
      execute(:get, REPO_COMMIT_URL.expand(repo_slug:, sha:).to_s)
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
        .then { |commit| self.class.parse_author_info(commit) }
    end

    # CI/CD

    def list_pipeline_selectors(repo_slug, branch_name = "main")
      sha = head(repo_slug, branch_name, sha_only: true)
      yaml_content = execute(:get, PIPELINE_YAML_URL.expand(repo_slug:, sha:).to_s, {}, false)
      pipeline_config = YAML.safe_load(yaml_content, aliases: true)
      selectors = []

      # Add default pipeline if it exists
      selectors << {name: "Default", type: "default", id: "default"} if pipeline_config["pipelines"]["default"]

      # Add custom pipelines
      pipeline_config["pipelines"]["custom"]&.each do |custom_name, _|
        selectors << {name: "Custom: #{custom_name}", id: "custom: #{custom_name}"}
      end

      selectors
    rescue Installations::Bitbucket::Error => e
      raise e if e.reason == :token_expired
      raise Installations::Error.new("Failed to fetch bitbucket-pipelines.yml: #{e.message}", reason: :pipeline_yaml_not_found)
    rescue => e
      raise Installations::Error.new("Failed to parse bitbucket-pipelines.yml: #{e.message}", reason: :pipeline_yaml_parse_error)
    end

    def trigger_pipeline!(repo_slug, pipeline_config, inputs, commit_hash, transforms)
      type, pattern = pipeline_config.split(":").map(&:strip)
      params = {
        json: {
          target: {
            commit: {
              hash: commit_hash,
              type: "commit"
            },
            type: "pipeline_commit_target",
            selector: {
              type:,
              pattern:
            }
          },
          variables: [
            {
              key: "VERSION_NAME",
              value: inputs[:build_version]
            },
            {
              key: "VERSION_CODE",
              value: inputs[:version_code]
            }
          ]
        }
      }

      execute(:post, PIPELINES_URL.expand(repo_slug:).to_s, params)
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
        .then { |pipeline| pipeline.presence || raise(Installations::Error.new("Could not trigger the workflow", reason: :workflow_trigger_failed)) }
    end

    def get_pipeline(repo_slug, pipeline_id)
      execute(:get, PIPELINE_URL.expand(repo_slug:, pipeline_id:).to_s)&.with_indifferent_access
    end

    def cancel_pipeline!(repo_slug, pipeline_id)
      execute(:post, STOP_PIPELINE_URL.expand(repo_slug:, pipeline_id:).to_s)
    end

    def get_file(repo_slug, file_name, transforms)
      find_file(LIST_FILES_URL.expand(repo_slug:).to_s, [], file_name)
        &.then { |file| Installations::Response::Keys.transform([file], transforms) }
        &.first
    end

    def download_artifact(artifact_url)
      download_url = fetch_redirect(artifact_url)
      return unless download_url
      Down::Http.download(download_url, follow: {max_hops: 1})
    end

    private

    def get_sha_for_ref(repo_slug, ref, type)
      if type == :branch
        head(repo_slug, ref, sha_only: true)
      elsif type == :tag
        get_tag(repo_slug, ref).dig("target", "hash")
      elsif type == :commit
        ref
      else
        raise ArgumentError, "Invalid ref type"
      end
    end

    MAX_PAGES = 10

    def find_file(url, files, file_name, page = 0)
      return if page == MAX_PAGES

      response = fetch_files(url)
      new_files = response["values"]
      next_page_url = response["next"]
      return if new_files.blank?

      files.concat(new_files)
      found_file = files.find { |f| f["name"] == file_name }
      return found_file if found_file.present?

      return if next_page_url.blank?
      find_file(next_page_url, files, file_name, page.succ)
    end

    def fetch_files(url)
      execute(:get, url)
    end

    def execute(verb, url, params = {}, parse_json = true)
      response = HTTP.auth("Bearer #{oauth_access_token}").public_send(verb, url, params)

      return if response.status.no_content?
      raise Installations::Bitbucket::Error.new({"error" => {"message" => "Service Unavailable"}}) if response.status.server_error?

      body = response.body.to_s
      parsed_body = body.safe_json_parse
      Rails.logger.debug { "Bitbucket API returned #{response.status} for #{url} with body - #{parsed_body}" }
      return (parse_json ? parsed_body : body) unless response.status.client_error?

      raise Installations::Error.new("Resource not found", reason: :not_found) if response.status.not_found?
      raise Installations::Bitbucket::Error.new(parsed_body)
    end

    def fetch_redirect(url)
      response = HTTP.auth("Bearer #{oauth_access_token}").headers("Content-Type" => "application/json").get(url)
      raise Installations::Bitbucket::Error.new({"error" => {"message" => "Service Unavailable"}}) if response.status.server_error?
      return response.headers["Location"] unless response.status.client_error?
      raise Installations::Bitbucket::Error.new(response.body.safe_json_parse)
    end

    def paginated_execute(verb, url, params = {}, values = [], page = 0)
      return values if page == MAX_PAGES
      body = execute(verb, url, params)
      new_values = body["values"]
      values.concat(new_values)

      next_page_url = body["next"]
      return values if next_page_url.blank?

      paginated_execute(verb, next_page_url, params, values, page + 1)
    end

    def webhook_params(url)
      {
        json: {
          description: "Tramline",
          url:,
          active: true,
          secret: nil,
          events: WEBHOOK_EVENTS
        }
      }
    end
  end
end

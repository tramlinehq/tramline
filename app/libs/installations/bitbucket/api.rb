module Installations
  class Bitbucket::Api
    require "down/http"

    include Vaultable
    attr_reader :oauth_access_token

    BASE_URL = "https://api.bitbucket.org/2.0"
    REPOS_URL = Addressable::Template.new "#{BASE_URL}/repositories/{workspace}"
    REPO_HOOKS_URL = Addressable::Template.new "#{BASE_URL}/repositories/{workspace}/{repo_slug}/hooks"
    REPO_HOOK_URL = Addressable::Template.new "#{BASE_URL}/repositories/{workspace}/{repo_slug}/hooks/{hook_id}"
    REPO_BRANCHES_URL = Addressable::Template.new "#{BASE_URL}/repositories/{workspace}/{repo_slug}/refs/branches"
    REPO_BRANCH_URL = Addressable::Template.new "#{BASE_URL}/repositories/{workspace}/{repo_slug}/refs/branches/{branch_name}"
    REPO_TAGS_URL = Addressable::Template.new "#{BASE_URL}/repositories/{workspace}/{repo_slug}/refs/tags"
    REPO_TAG_URL = Addressable::Template.new "#{BASE_URL}/repositories/{workspace}/{repo_slug}/refs/tags/{tag_name}"
    DIFFSTAT_URL = Addressable::Template.new "#{BASE_URL}/repositories/{workspace}/{repo_slug}/diffstat/{from_sha}..{to_sha}"
    PRS_URL = Addressable::Template.new "#{BASE_URL}/repositories/{workspace}/{repo_slug}/pullrequests"
    PR_URL = Addressable::Template.new "#{BASE_URL}/repositories/{workspace}/{repo_slug}/pullrequests/{pr_number}"
    PR_MERGE_URL = Addressable::Template.new "#{BASE_URL}/repositories/{workspace}/{repo_slug}/pullrequests/{pr_number}/merge"
    REPO_COMMITS_URL = Addressable::Template.new "#{BASE_URL}/repositories/{workspace}/{repo_slug}/commits"
    REPO_COMMIT_URL = Addressable::Template.new "#{BASE_URL}/repositories/{workspace}/{repo_slug}/commit/{sha}"
    GET_COMMIT_URL = Addressable::Template.new "#{BASE_URL}/repositories/{workspace}/{repo_slug}/commit/{commit_sha}"

    WORKSPACES_URL = "#{BASE_URL}/workspaces"
    PIPELINES_CONFIG_URL = Addressable::Template.new "#{BASE_URL}/repositories/{workspace}/{repo_slug}/pipelines_config"
    PIPELINES_URL = Addressable::Template.new "#{BASE_URL}/repositories/{workspace}/{repo_slug}/pipelines"
    PIPELINE_URL = Addressable::Template.new "#{BASE_URL}/repositories/{workspace}/{repo_slug}/pipelines/{pipeline_id}"
    LIST_FILES_URL = Addressable::Template.new "#{BASE_URL}/repositories/{workspace}/{repo_slug}/downloads"
    GET_FILE_URL = Addressable::Template.new "#{BASE_URL}/repositories/{workspace}/{repo_slug}/downloads/{file_name}"

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
    end

    def initialize(oauth_access_token, workspace)
      @oauth_access_token = oauth_access_token
      @workspace = workspace
    end

    def list_workspaces(transforms)
      execute(:get, WORKSPACES_URL)
        .then { |responses| Installations::Response::Keys.transform(responses["values"], transforms) }
    end

    def create_repo_webhook!(repo_slug, url, transforms)
      execute(:post, REPO_HOOKS_URL.expand(workspace:, repo_slug:).to_s, webhook_params(url))
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    def update_repo_webhook!(repo_slug, hook_id, url, transforms)
      execute(:put, REPO_HOOK_URL.expand(workspace:, repo_slug:, hook_id:).to_s, webhook_params(url))
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    def find_webhook(repo_slug, hook_id, transforms)
      execute(:get, REPO_HOOK_URL.expand(workspace:, repo_slug:, hook_id:).to_s)
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

      execute(:post, REPO_BRANCHES_URL.expand(workspace:, repo_slug:).to_s, params)
    end

    def create_tag!(repo_slug, tag_name, sha)
      params = {
        json: {
          name: tag_name,
          target: {hash: sha}
        }
      }

      execute(:post, REPO_TAGS_URL.expand(workspace:, repo_slug:).to_s, params)
    end

    def branch_exists?(repo_slug, branch_name)
      get_branch(repo_slug, branch_name).present?
    end

    def tag_exists?(repo_slug, tag_name)
      get_tag(repo_slug, tag_name).present?
    end

    def create_pr!(repo_slug, to, from, title, description, transforms)
      params = {
        json: {
          title:,
          source: {branch: {name: from}},
          destination: {branch: {name: to}},
          description:
        }
      }

      execute(:post, PRS_URL.expand(workspace:, repo_slug:).to_s, params)
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

      execute(:get, PRS_URL.expand(workspace:, repo_slug:).to_s, params)
        .then { |response| Installations::Response::Keys.transform(response["values"], transforms) }
        .first
    end

    def get_pr(repo, pr_number, transforms)
      # TODO: Not Found throws a JSON::ParserError
      execute(:get, PR_URL.expand(workspace:, repo_slug: repo, pr_number:).to_s)
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    def merge_pr!(repo_slug, pr_number)
      execute(:post, PR_MERGE_URL.expand(workspace: @workspace, repo_slug:, pr_number:).to_s)
    end

    def commits_between(repo, from_branch, to_branch, transforms)
      params = {
        params: {
          include: to_branch,
          exclude: from_branch
        }
      }

      paginated_execute(:get, REPO_COMMITS_URL.expand(workspace: @workspace, repo_slug: repo).to_s, params)
        .then { |commits| Installations::Response::Keys.transform(commits, transforms) }
    end

    def diff?(repo_slug, from_branch, to_branch)
      from_sha = get_branch_short_sha(repo_slug, from_branch)
      to_sha = get_branch_short_sha(repo_slug, to_branch)

      execute(:get, DIFFSTAT_URL.expand(workspace:, repo_slug:, from_sha:, to_sha:).to_s)
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
      execute(:get, REPO_COMMIT_URL.expand(workspace: @workspace, repo_slug:, sha:).to_s)
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    def list_repos(transforms)
      execute(:get, REPOS_URL.expand(workspace:).to_s)
        .then { |responses| Installations::Response::Keys.transform(responses["values"], transforms) }
    end

    def list_pipelines(repo_slug, transforms)
      execute(:get, PIPELINES_URL.expand(workspace:, repo_slug:).to_s)
        .then { |responses| Installations::Response::Keys.transform(responses["values"], transforms) }
    end

    def get_pipeline_config(repo_slug)
      execute(:get, PIPELINES_CONFIG_URL.expand(workspace:, repo_slug:).to_s)
    end

    def trigger_pipeline(repo_slug, _pipeline_config, _branch_name, inputs, commit_hash, transforms) # TODO: pipeline config
      params = {
        json: {
          target: {
            commit: {
              hash: commit_hash,
              type: "commit"
            },
            type: "pipeline_commit_target",
            selector: {
              type: "custom",
              pattern: "android-debug-apk"
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

      execute(:post, PIPELINES_URL.expand(workspace:, repo_slug:).to_s, params)
        .then { |response| Installations::Response::Keys.transform([response], transforms) }
        .first
    end

    def get_pipeline(repo_slug, pipeline_id)
      execute(:get, PIPELINE_URL.expand(workspace:, repo_slug:, pipeline_id:).to_s)&.with_indifferent_access
    end

    def get_file(repo_slug, file_name, transforms)
      find_file(LIST_FILES_URL.expand(workspace:, repo_slug:).to_s, [], file_name)
        &.then { |file| Installations::Response::Keys.transform([file], transforms) }
        &.first
    end

    def download_artifact(download_url)
      Down::Http.download(download_url, follow: {max_hops: 2})
    end

    private

    attr_reader :workspace

    def get_branch(repo_slug, branch_name)
      execute(:get, REPO_BRANCH_URL.expand(workspace:, repo_slug:, branch_name:).to_s)
    end

    def get_tag(repo_slug, tag_name)
      execute(:get, REPO_TAG_URL.expand(workspace:, repo_slug:, tag_name:).to_s)
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
      list_files(next_page_url, files, file_name, page.inc)
    end

    def fetch_files(url)
      execute(:get, url)
    end

    def execute(verb, url, params = {})
      response = HTTP.auth("Bearer #{oauth_access_token}").public_send(verb, url, params)
      body = JSON.parse(response.body.to_s)
      return body unless error?(response.status)
      raise Installations::Bitbucket::Error.new(body)
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

    def error?(code)
      code.between?(400, 499)
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

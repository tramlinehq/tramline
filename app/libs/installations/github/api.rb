module Installations
  require "down/http"

  class Github::Api
    include Vaultable
    attr_reader :app_name, :installation_id, :jwt, :client

    WEBHOOK_NAME = "web"
    WEBHOOK_EVENTS = %w[push pull_request]
    LIST_WORKFLOWS_LIMIT = 99
    RERUN_FAILED_JOBS_URL = Addressable::Template.new "https://api.github.com/repos/{repo}/actions/runs/{run_id}/rerun-failed-jobs"

    def initialize(installation_id)
      @app_name = creds.integrations.github.app_name
      @installation_id = installation_id
      @jwt = Installations::Github::Jwt.new(creds.integrations.github.app_id)

      set_client
    end

    def self.find_biggest(artifacts)
      artifacts.max_by { |artifact| artifact["size_in_bytes"] }
    end

    def self.filter_by_name(artifacts, name_pattern)
      return artifacts if name_pattern.blank?
      artifacts.filter { |artifact| artifact["name"].downcase.include? name_pattern }.presence || artifacts
    end

    def get_installation(id, transforms)
      execute do
        Octokit::Client.new(bearer_token: jwt.get)
          .installation(id)
          .then { |responses| Installations::Response::Keys.transform([responses], transforms) }
          .first
      end
    end

    def list_workflows(repo, transforms)
      execute do
        @client
          .workflows(repo, {per_page: LIST_WORKFLOWS_LIMIT})
          .then { |response| response[:workflows] }
          .then { |workflows| workflows.select { |workflow| workflow[:state] == "active" } }
          .then { |responses| Installations::Response::Keys.transform(responses, transforms) }
      end
    end

    def find_workflow_run(repo, workflow, branch, head_sha, transforms)
      options = {
        branch:,
        head_sha:
      }

      execute do
        @client
          .workflow_runs(repo, workflow, options)
          .then { |response| response[:workflow_runs] }
          .then { |workflow_runs| workflow_runs.sort_by { |workflow_run| workflow_run[:run_number] }.reverse! }
          .then { |responses| Installations::Response::Keys.transform(responses, transforms) }
          .first
          .then { |run| run&.presence || raise(Installations::Error.new("Could not find the workflow run", reason: :workflow_run_not_found)) }
      end
    end

    def get_workflow_run(repo, run_id)
      execute do
        @client
          .workflow_run(repo, run_id)
          .then { |run| run.to_h.presence || raise(Installations::Error.new("Could not find the workflow run", reason: :workflow_run_not_found)) }
      end
    end

    def list_repos(transforms)
      execute do
        @client
          .list_app_installation_repositories
          .then { |response| response[:repositories] }
          .then { |responses| Installations::Response::Keys.transform(responses, transforms) }
      end
    end

    def run_workflow!(repo, id, ref, inputs, commit_hash, json_inputs_enabled = false)
      inputs = if json_inputs_enabled
        inputs
          .slice(:version_code, :build_notes)
          .merge(version_name: inputs[:build_version], commit_ref: commit_hash)
          .compact
          .to_json
          .then { {"tramline-input" => _1} }
      else
        {
          versionCode: inputs[:version_code],
          versionName: inputs[:build_version],
          buildNotes: inputs[:build_notes]
        }.compact
      end

      execute do
        @client
          .workflow_dispatch(repo, id, ref, inputs: inputs)
          .then { |ok| ok.presence || raise(Installations::Error.new("Could not trigger the workflow", reason: :workflow_trigger_failed)) }
      end
    end

    def cancel_workflow!(repo, run_id)
      execute do
        @client.cancel_workflow_run(repo, run_id)
      end
    end

    def retry_workflow!(repo, run_id)
      execute_custom do |custom_client|
        custom_client.post(
          RERUN_FAILED_JOBS_URL
            .expand(repo:, run_id:)
            .to_s
            .then { |url| URI.decode_www_form_component(url) },
          {}
        )
      end
    end

    def create_repo_webhook!(repo, url, transforms)
      execute do
        @client.create_hook(
          repo,
          WEBHOOK_NAME,
          {
            url:,
            content_type: "json"
          },
          {
            events: WEBHOOK_EVENTS,
            active: true
          }
        ).then { |response| Installations::Response::Keys.transform([response], transforms) }.first
      end
    end

    def update_repo_webhook!(repo, id, url, transforms)
      execute do
        @client.edit_hook(
          repo,
          id,
          WEBHOOK_NAME,
          {
            url:,
            content_type: "json"
          },
          {
            events: WEBHOOK_EVENTS,
            active: true
          }
        ).then { |response| Installations::Response::Keys.transform([response], transforms) }.first
      end
    end

    def find_webhook(repo, id, transforms)
      execute do
        @client
          .hook(repo, id)
          .then { |response| Installations::Response::Keys.transform([response], transforms) }
          .first
      end
    end

    def create_branch!(repo, source_name, new_branch_name, source_type: :branch)
      execute do
        sha =
          case source_type
          when :branch
            head(repo, source_name)
          when :commit
            source_name
          when :tag
            @client.ref(repo, "tags/#{source_name}")[:object][:sha]
          else
            raise ArgumentError, "source can only be a branch, tag or commit"
          end

        @client.create_ref(repo, "heads/#{new_branch_name}", sha)
      end
    end

    def create_tag!(repo, name, sha)
      execute do
        @client.create_ref(repo, "refs/tags/#{name}", sha)
      end
    end

    def create_annotated_tag!(repo, name, branch_name, message, tagger_name, tagger_email)
      execute do
        object_sha = head(repo, branch_name)
        type = "commit"
        tagged_at = Time.current

        @client
          .create_tag(repo, name, message, object_sha, type, tagger_name, tagger_email, tagged_at)
          .then { |resp| @client.create_ref(repo, "refs/tags/#{name}", resp[:sha]) }
      end
    end

    # creates a lightweight tag and a GitHub release simultaneously
    def create_release!(repo, tag_name, branch_name, release_notes = nil)
      options = {
        target_commitish: branch_name,
        name: tag_name,
        body: release_notes.presence,
        generate_release_notes: release_notes.blank?
      }.compact
      execute do
        raise Installations::Error.new("Should not create a tag", reason: :tag_reference_already_exists) if tag_exists?(repo, tag_name)
        @client.create_release(repo, tag_name, options)
      end
    end

    def tag_exists?(repo, tag_name)
      execute do
        # NOTE: The API returns a list of matching tags if the exact match doesn't exist
        # It returns a single element if there is an exact match
        !@client.ref(repo, "tags/#{tag_name}").is_a?(Array)
      end
    rescue Installations::Github::Error => e
      raise e if e.reason != :not_found
      false
    end

    def branch_exists?(repo, branch_name)
      execute do
        @client.branch(repo, branch_name).present?
      end
    end

    def create_pr!(repo, to, from, title, body, transforms)
      raise Installations::Error.new("Should not create a Pull Request without a diff", reason: :pull_request_without_commits) unless diff?(repo, to, from)

      execute do
        @client
          .create_pull_request(repo, to, from, title, body)
          .then { |response| Installations::Response::Keys.transform([response], transforms) }
          .first
      end
    end

    def find_pr(repo, to, from, transforms)
      execute do
        @client
          .pull_requests(repo, {head: from, base: to})
          .then { |response| Installations::Response::Keys.transform(response, transforms) }
          .first
      end
    end

    def get_pr(repo, pr_number, transforms)
      execute do
        @client
          .pull_request(repo, pr_number)
          .then { |response| Installations::Response::Keys.transform([response], transforms) }
          .first
      end
    end

    def merge_pr!(repo, pr_number)
      execute do
        @client.merge_pull_request(repo, pr_number)
      end
    end

    def commits_between(repo, from_branch, to_branch, transforms)
      execute do
        @client
          .compare(repo, from_branch, to_branch)
          .dig(:commits)
          .then { |commits| Installations::Response::Keys.transform(commits, transforms) }
      end
    end

    def diff?(repo, from_branch, to_branch)
      execute do
        @client
          .compare(repo, from_branch, to_branch)
          .dig(:files)
          .present?
      end
    end

    def head(repo, working_branch_name, sha_only: true, commit_transforms: nil)
      raise ArgumentError, "transforms must be supplied when querying head object" if !sha_only && !commit_transforms

      execute do
        obj = @client.ref(repo, "heads/#{working_branch_name}")[:object]
        if obj[:type].eql? "commit"
          return obj[:sha] if sha_only
          return get_commit(repo, obj[:sha], commit_transforms)
        end
      end
    end

    def get_commit(repo, sha, commit_transforms)
      @client.commit(repo, sha).then { |commit| Installations::Response::Keys.transform([commit], commit_transforms) }.first
    end

    def assign_pr(repo, pr_number, login)
      execute do
        @client.add_assignees(repo, pr_number, [login])
      end
    end

    def cherry_pick_pr(repo, branch, sha, patch_branch_name, pr_title_prefix, transforms)
      # get_head_commit on working branch -- 1 api call
      # get commit we need to cherry pick - 1 api call
      # create a temp commit with correct tree and parent - 1 api call
      # create a patch branch on that commit - 1 api call
      # create cherry picked commit - 1 api call
      # force update ref of patch branch - 1 api call
      # create a PR - 1 api call

      # TOTAL - 7 api calls
      execute do
        branch_head = @client.branch(repo, branch)[:commit]
        branch_tree_sha = branch_head[:commit][:tree][:sha]
        commit_to_pick = @client.commit(repo, sha)
        commit_to_pick_sha = commit_to_pick[:parents]&.last&.dig(:sha)
        commit_to_pick_msg = commit_to_pick.dig(:commit, :message)
        commit_to_pick_login = commit_to_pick.dig(:author, :login)
        cherry_commit_authors = commit_to_pick.dig(:commit).to_h.slice(:author, :committer)

        temp_commit_message = "Temporary Commit by Tramline"
        temp_commit_sha = @client.create_commit(repo, temp_commit_message, branch_tree_sha, commit_to_pick_sha)[:sha]
        @client.create_ref(repo, "heads/#{patch_branch_name}", temp_commit_sha)

        merge_tree = @client.merge(repo, patch_branch_name, sha).dig(:commit, :tree, :sha)
        cherry_commit = @client.create_commit(repo, commit_to_pick_msg, merge_tree, branch_head[:sha], cherry_commit_authors)[:sha]
        @client.update_ref(repo, "heads/#{patch_branch_name}", cherry_commit, true)

        patch_pr_description = <<~TEXT
          - Cherry-pick #{sha} commit
          - Authored by: @#{commit_to_pick_login}

          #{commit_to_pick_msg}
        TEXT
        patch_pr_title = "#{pr_title_prefix} #{commit_to_pick_msg.split("\n").first}".gsub(/\s*\(#\d+\)/, "").squish

        @client
          .create_pull_request(repo, branch, patch_branch_name, patch_pr_title, patch_pr_description)
          .then { |response| Installations::Response::Keys.transform([response], transforms) }
          .first
          .tap { |pr| assign_pr(repo, pr[:number], commit_to_pick_login) }
      end
    rescue Installations::Error => e
      @client.delete_branch(repo, patch_branch_name) if e.reason == :merge_conflict
      raise e
    end

    def enable_auto_merge(owner, repo, pr_number)
      find_pr_id_query = <<-GRAPHQL
        query {
          repository(owner: "#{owner}", name: "#{repo}") {
            pullRequest(number: #{pr_number}) {
              id
            }
          }
        }
      GRAPHQL

      response = client.post "/graphql", {query: find_pr_id_query}.to_json
      pull_request_id = response.dig(:data, :repository, :pullRequest, :id)
      raise Installations::Error.new("Could not find the Pull Request", reason: :not_found) unless pull_request_id

      enable_auto_merge = <<-GRAPHQL
        mutation {
          enablePullRequestAutoMerge(input: {pullRequestId: "#{pull_request_id}"}) {
            pullRequest {
              id
            }
          }
        }
      GRAPHQL

      client.post "/graphql", {query: enable_auto_merge}.to_json
    end

    def artifact_download_url(artifact)
      HTTP
        .auth("Bearer #{@client.access_token}")
        .get(artifact["archive_download_url"])
        .then { |resp| resp.headers["Location"] }
    end

    def artifact_io_stream(url)
      # FIXME: return an IO stream instead of a TempFile
      # See issue: https://github.com/janko/down/issues/70
      Down::Http.download(url)
    end

    def artifacts(artifacts_url, transforms)
      HTTP
        .auth("Bearer #{@client.access_token}")
        .get(artifacts_url)
        .then { |resp| JSON.parse(resp.to_s) }
        .then { |parsed_resp| Installations::Response::Keys.transform(parsed_resp["artifacts"], transforms) }
    end

    def execute
      yield
    rescue Octokit::Unauthorized
      set_client
      retry
    rescue Octokit::NotFound, Octokit::UnprocessableEntity, Octokit::MethodNotAllowed, Octokit::Conflict => e
      raise Installations::Github::Error.new(e)
    end

    API_VERSION = "2022-11-28"
    ACCEPT_HEADER = "application/vnd.github+json"

    def execute_custom
      execute do
        token = @client.access_token
        new_client = HTTP.auth("Bearer #{token}").headers(:accept => ACCEPT_HEADER, "X-GitHub-Api-Version" => API_VERSION)

        response = yield(new_client)

        response_params = {
          status: response.status,
          body: response.body,
          response_headers: response.headers.to_h.with_indifferent_access
        }

        if (error = Octokit::Error.from_response(response_params))
          raise error
        end
      end
    end

    def set_client
      client = Octokit::Client.new(bearer_token: jwt.get)
      installation_token = client.create_app_installation_access_token(installation_id)[:token]
      @client ||= Octokit::Client.new(access_token: installation_token)
    end
  end
end

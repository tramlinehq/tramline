module Installations
  require "down/http"

  class Github::Api
    include Vaultable
    attr_reader :app_name, :installation_id, :jwt, :client

    WEBHOOK_NAME = "web"
    WEBHOOK_EVENTS = %w[push]
    LIST_WORKFLOWS_LIMIT = 99
    RERUN_FAILED_JOBS_URL = Addressable::Template.new "https://api.github.com/repos/{repo}/actions/runs/{run_id}/rerun-failed-jobs"

    def initialize(installation_id)
      @app_name = creds.integrations.github.app_name
      @installation_id = installation_id
      @jwt = Installations::Github::Jwt.new(creds.integrations.github.app_id)

      set_client
    end

    def get_installation(id, transforms)
      execute do
        Octokit::Client.new(bearer_token: jwt.get)
          .installation(id)
          .tap { |response| Rails.logger.info "Github response", response }
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
          .then { |run| run&.presence || raise(Installations::Errors::WorkflowRunNotFound) }
      end
    end

    def get_workflow_run(repo, run_id)
      execute do
        @client
          .workflow_run(repo, run_id)
          .then { |run| run.to_h.presence || raise(Installations::Errors::WorkflowRunNotFound) }
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

    def run_workflow!(repo, id, ref, inputs)
      inputs = {
        versionCode: inputs[:version_code],
        versionName: inputs[:build_version],
        buildNotes: inputs[:build_notes]
      }.compact

      execute do
        @client
          .workflow_dispatch(repo, id, ref, inputs: inputs)
          .then { |ok| ok.presence || raise(Installations::Errors::WorkflowTriggerFailed) }
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

    def find_webhook(repo, id, transforms)
      execute do
        @client
          .hook(repo, id)
          .then { |response| Installations::Response::Keys.transform([response], transforms) }
          .first
      end
    end

    def create_branch!(repo, working_branch_name, new_branch_name)
      execute do
        @client.create_ref(repo, "heads/#{new_branch_name}", head(repo, working_branch_name))
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
    def create_release!(repo, tag_name, branch_name)
      execute do
        raise Installations::Errors::TagReferenceAlreadyExists if tag_exists?(repo, tag_name)
        @client.create_release(repo, tag_name, target_commitish: branch_name, generate_release_notes: false)
      end
    end

    def tag_exists?(repo, tag_name)
      @client.ref(repo, "tags/#{tag_name}").present?
    rescue Octokit::NotFound
      false
    end

    def create_pr!(repo, to, from, title, body)
      execute do
        @client.create_pull_request(repo, to, from, title, body)
      end
    end

    def find_pr(repo, to, from)
      execute do
        @client.pull_requests(repo, {head: from, base: to}).first
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

    def head(repo, working_branch_name)
      execute do
        # FIXME: this method is unsupported and could get deprecated, find a way around it
        @client.commits(repo, sha: working_branch_name).first[:sha]
      end
    end

    def self.find_biggest(artifacts)
      artifacts.max_by { |artifact| artifact["size_in_bytes"] }
    end

    def artifact_io_stream(artifact)
      # FIXME: return an IO stream instead of a TempFile
      # See issue: https://github.com/janko/down/issues/70
      Down::Http.download(artifact["archive_download_url"],
        headers: {"Authorization" => "Bearer #{@client.access_token}"},
        follow: {max_hops: 1})
    end

    def artifacts(artifacts_url)
      HTTP
        .auth("Bearer #{@client.access_token}")
        .get(artifacts_url)
        .then { |resp| JSON.parse(resp.to_s)["artifacts"] }
    end

    def execute
      yield
    rescue Octokit::Unauthorized
      set_client
      retry
    rescue Octokit::NotFound, Octokit::UnprocessableEntity, Octokit::MethodNotAllowed => e
      raise Installations::Github::Error.handle(e)
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

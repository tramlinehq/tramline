module Installations
  require "down/http"

  class Github::Api
    include Vaultable
    attr_reader :app_name, :installation_id, :jwt, :client

    WEBHOOK_NAME = "web"
    WEBHOOK_EVENTS = %w[workflow_run push]

    def initialize(installation_id)
      @app_name = creds.integrations.github.app_name
      @installation_id = installation_id
      @jwt = Github::Jwt.new(creds.integrations.github.app_id)

      set_client
    end

    def list_workflows(repo)
      execute do
        @client
          .workflows(repo)
          .then { |response| response[:workflows] }
          .then { |workflows| workflows.select { |workflow| workflow[:state] == "active" } }
          .then { |workflows| workflows.map { |workflow| workflow.to_h.slice(:id, :name) } }
          .then { |responses| Installations::Response::Keys.normalize(responses) }
      end
    end

    def find_workflow_run(repo, workflow, branch, head_sha)
      options = {
        branch:,
        head_sha:
      }

      execute do
        @client
          .workflow_runs(repo, workflow, options)
          .then { |response| response[:workflow_runs] }
          .then { |workflow_runs| workflow_runs.sort_by { |workflow_run| workflow_run[:run_number] }.reverse! }
          .first
          .then { |run| run&.to_h.presence || raise(Installations::Errors::WorkflowRunNotFound) }
      end
    end

    def get_workflow_run(repo, run_id)
      execute do
        @client
          .workflow_run(repo, run_id)
          .then { |run| run.to_h.presence || raise(Installations::Errors::WorkflowRunNotFound) }
      end
    end

    def list_repos
      execute do
        @client
          .list_app_installation_repositories
          .then { |response| response[:repositories] }
          .then { |repos| repos.map { |repository| repository.to_h.slice(:id, :full_name) } }
          .then { |responses| Installations::Response::Keys.normalize(responses) }
      end
    end

    class WorkflowTriggerFailed < StandardError; end

    def run_workflow!(repo, id, ref, inputs)
      inputs = {
        versionCode: inputs[:version_code],
        versionNumber: inputs[:build_version]
      }

      execute do
        @client
          .workflow_dispatch(repo, id, ref, inputs: inputs)
          .then { |ok| ok.presence || raise(Installations::Errors::WorkflowTriggerFailed) }
      end
    end

    def create_repo_webhook!(repo, url)
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
        )
      end
    end

    def create_branch!(repo, working_branch_name, new_branch_name)
      execute do
        @client.create_ref(repo, "heads/#{new_branch_name}", head(repo, working_branch_name))
      end
    end

    def create_tag!(repo, name, branch_name)
      execute do
        @client.create_ref(repo, "refs/tags/#{name}", head(repo, branch_name))
      end
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

    def merge_pr!(repo, pr_number)
      execute do
        @client.merge_pull_request(repo, pr_number)
      end
    end

    def head(repo, working_branch_name)
      execute do
        @client.commits(repo, sha: working_branch_name).first[:sha]
      end
    end

    def artifact_filename(archive_download_url)
      header = Down::Http.open(archive_download_url,
        headers: {"Authorization" => "Bearer #{@client.access_token}"},
        follow: {max_hops: 1}).data[:headers]["Content-Disposition"]
      Down::Utils.filename_from_content_disposition(header)
    end

    def artifact_io_stream(archive_download_url)
      # FIXME: return an IO stream instead of a TempFile
      # See issue: https://github.com/janko/down/issues/70
      Down::Http.download(archive_download_url,
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

    def set_client
      client = Octokit::Client.new(bearer_token: jwt.get)
      installation_token = client.create_app_installation_access_token(installation_id)[:token]
      @client ||= Octokit::Client.new(access_token: installation_token)
    end
  end
end

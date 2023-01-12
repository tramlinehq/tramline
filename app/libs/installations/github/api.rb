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

    def list_workflows(repo, transforms)
      execute do
        @client
          .workflows(repo)
          .then { |response| response[:workflows] }
          .then { |workflows| workflows.select { |workflow| workflow[:state] == "active" } }
          .then { |responses| Installations::Response::Keys.transform(responses, transforms) }
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
          .then { |workflow_runs| workflow_runs.map { |workflow_run| workflow_run.to_h.slice(:id, :html_url) } }
          .then { |responses| Installations::Response::Keys.normalize(responses, :workflow_runs) }
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
        versionName: inputs[:build_version]
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
        object_sha = head(repo, branch_name)
        @client.create_ref(repo, "refs/tags/#{name}", object_sha)
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
        @client.create_release(repo, tag_name, target_commitish: branch_name, generate_release_notes: true)
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

    def set_client
      client = Octokit::Client.new(bearer_token: jwt.get)
      installation_token = client.create_app_installation_access_token(installation_id)[:token]
      @client ||= Octokit::Client.new(access_token: installation_token)
    end
  end
end

class WebhookHandlers::Github::Push
  Response = Struct.new(:status, :body)
  attr_reader :payload, :train

  def self.process(train, payload)
    new(train, payload).process
  end

  def initialize(train, payload)
    @train = train
    @payload = payload
  end

  def process
    return Response.new(:accepted) if valid_tag?

    if valid_repo_and_branch?

      if train.commit_listeners.exists?(branch_name:)
        commit = payload["head_commit"]
        commit_record = Releases::Commit.create!(train:,
          train_run: release,
          commit_hash: commit["id"],
          message: commit["message"],
          timestamp: commit["timestamp"],
          author_name: commit["author"]["name"],
          author_email: commit["author"]["email"],
          url: commit["url"])

        if release
          current_step = release.step_runs.last&.step&.step_number || 1

          train.steps.where("step_number <= ?", current_step).each do |step|
            step_run = release.step_runs.create!(step:, scheduled_at: Time.current, status: "on_track", commit: commit_record)
            step_run.automatons!
          end
        end
        train.bump_version!(:patch)
        release.update(release_version: train.version_current)

        message = "New push to the branch #{payload["ref"].delete_prefix("refs/heads/")} with \
    message #{payload["head_commit"]["message"]}"
        Automatons::Notify.dispatch!(train:, message:)
      end
      Response.new(:accepted)
    else
      Response.new(:unprocessable_entity)
    end
  end

  private

  def valid_branch?
    payload["ref"]&.include?("refs/heads/")
  end

  def valid_tag?
    payload["ref"]&.include?("refs/tags/")
  end

  def branch_name
    payload["ref"].delete_prefix("refs/heads/") if valid_branch?
  end

  def repository_name
    payload["repository"]["full_name"]
  end

  def valid_repo_and_branch?
    (train.app.config&.code_repository_name == repository_name) if branch_name
  end

  def release
    train.active_run
  end
end

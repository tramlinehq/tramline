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
    return Response.new(:accepted) unless release.committable? # FIXME: this is sometimes barfing, esp in finalize

    if valid_repo_and_branch?
      if train.commit_listeners.exists?(branch_name:)
        commit = payload["head_commit"]

        Releases::Commit.transaction do
          commit_record = Releases::Commit.create!(train:,
            train_run: release,
            commit_hash: commit["id"],
            message: commit["message"],
            timestamp: commit["timestamp"],
            author_name: commit["author"]["name"],
            author_email: commit["author"]["email"],
            url: commit["url"])

          train.bump_version!(:patch) if release.step_runs.any?

          if release
            current_step = release.current_step || 1

            train.steps.where("step_number <= ?", current_step).order("step_number").each do |step|
              if step.step_number < current_step
                Services::TriggerStepRun.call(step, commit_record, false)
              else
                Services::TriggerStepRun.call(step, commit_record)
              end
            end
          end

          release.update(release_version: train.version_current)
          notify_release_start!(payload)
        end
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
    @release ||= train.active_run
  end

  def notify_release_start!(payload)
    return unless release.commits.size.eql?(1)

    notifier =
      Notifiers::Slack::ReleaseStarted.render_json(
        train_name: train.name,
        version_number: train.version_current,
        branch_name: payload["ref"].delete_prefix("refs/heads/"),
        commit_msg: payload["head_commit"]["message"]
      )

    Automatons::Notify.dispatch!(
      train:,
      message: "New Release!",
      text_block: notifier
    )
  end
end

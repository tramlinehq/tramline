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
    if valid_repo_and_branch?

      if train.commit_listeners.exists?(branch_name:)
        payload['commits'].each do |commit|
          Releases::Commit.create!(train:,
                                   train_run: release,
                                   commit_hash: commit['id'],
                                   message: commit['message'],
                                   timestamp: commit['timestamp'],
                                   author_name: commit['author']['name'],
                                   author_email: commit['author']['email'],
                                   url: commit['url'])
        end
      end

      if release
        current_step = release.step_runs.last&.step&.step_number

        train.steps.where('step_number <= ?', current_step).each do |step|
          step_run = release.step_runs.create(step:, scheduled_at: Time.current, status: 'on_track')
          step_run.automatons!
        end
      end
      message = "New push to the branch #{payload['ref'].delete_prefix('refs/heads/')} with \
    message #{payload['head_commit']['message']}"
      Automatons::Notify.dispatch!(train:, message:)
      Response.new(:accepted)
    else
      Response.new(:unprocessable_entity)
    end
  end

  private

  def valid_branch?
    payload['ref']&.include?('refs/heads/')
  end

  def branch_name
    payload['ref'].delete_prefix('refs/heads/') if valid_branch?
  end

  def repository_name
    payload['repository']['full_name']
  end

  def valid_repo_and_branch?
    (train.app.config&.code_repository_name == repository_name) if branch_name
  end

  def release
    train.active_run
  end
end

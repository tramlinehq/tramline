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

      if train.commit_listners.exists?(branch_name:)
        payload['commits'].each do |commit|
          Releases::Commit.create!(train:,
                                   commit_hash: commit['id'],
                                   message: commit['message'],
                                   timestamp: commit['timestamp'],
                                   author_name: commit['author']['name'],
                                   author_email: commit['author']['email'],
                                   url: commit['url'])
        end
      end

      train.steps.each do |step|
        Automatons::Workflow.dispatch!(step:, ref: branch_name)
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

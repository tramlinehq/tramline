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
      # run step
    end
    Response.new(:accepted)
  end

  private

  def validate_repo_and_branch
    return false unless branch_name

    (app.config.code_repository.values.first == repository_name)
  end

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
    (app.config.code_repository.values.first == repository_name) if branch_name
  end
end

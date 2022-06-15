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
    Response.new(:accepted, branch_name)
    # TODO: filter commits from the branche(es) we care about
    # Run train steps from first to current to generate builds
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
    payload['ref'].split('/').last if valid_branch?
  end

  def repository_name
    payload['repository']['full_name']
  end

  def valid_repo_and_branch?
    (app.config.code_repository.values.first == repository_name) if branch_name
  end
end

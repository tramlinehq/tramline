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

  def branch_name
    return nil unless payload.key?('ref') && payload['ref'].include?('refs/heads/')

    payload['ref'].split('/').last
  end

  def repository_name
    payload['repository']['full_name']
  end

  def validate_repo_and_branch
    return false unless branch_name 

    (app.config.code_repository.values.first == repository_name)
  end
end

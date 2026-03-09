class Webhooks::Base
  include Loggable
  include Memery

  GITHUB = Webhooks::Github
  GITLAB = Webhooks::Gitlab
  BITBUCKET = Webhooks::Bitbucket

  attr_reader :payload, :train

  def self.process(train, payload)
    new(train, payload).process
  rescue => e
    elog(e, level: :warn)
  end

  def initialize(train, payload)
    @train = train
    @payload = payload
  end

  def release
    @release ||= train.active_runs.for_branch(branch_name)
  end

  private

  delegate :vcs_provider, to: :train
end

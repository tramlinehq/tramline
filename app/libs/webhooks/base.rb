class Webhooks::Base
  include Memery

  GITHUB = Webhooks::Github
  GITLAB = Webhooks::Gitlab
  BITBUCKET = Webhooks::Bitbucket

  attr_reader :payload, :train

  def self.process(train, payload)
    new(train, payload).process
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

class Coordinators::Webhooks::Base
  include SiteHttp
  include Memery

  GITHUB = Coordinators::Webhooks::Github
  GITLAB = Coordinators::Webhooks::Gitlab
  BITBUCKET = Coordinators::Webhooks::Bitbucket

  attr_reader :payload, :train

  def self.process(train, payload)
    new(train, payload).process
  end

  def initialize(train, payload)
    @train = train
    @payload = payload
  end

  def release
    @release ||= train.active_runs.find_active_for_train(train.id)
  end

  private

  delegate :vcs_provider, to: :train
end

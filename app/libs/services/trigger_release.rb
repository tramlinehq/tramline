class Services::TriggerRelease
  include Rails.application.routes.url_helpers

  def self.call(*args)
    new(*args).call
  end

  attr_reader :train, :starting_time

  def initialize(train)
    @train = train
    @starting_time = Time.current
  end

  def call
    return if train.inactive?
    return if train.steps.empty?

    create_run_record
    create_branches
    create_webhooks
    setup_webhook_listners
    run_first_step
  end

  private

  def create_run_record
    train.runs.create(was_run_at: starting_time, code_name: 1, scheduled_at: starting_time, status: :on_track)
  end

  def create_branches
    installation.create_branch!(repo, working_branch, new_branch_name)
  end

  def create_webhooks
    installation.create_repo_webhook!(repo, webhook_url)
  end

  def setup_webhook_listners; end

  def run_first_step; end

  def installation
    @installation ||= train.ci_cd_provider.installation
  end

  def repo
    train.app.config.code_repository_name
  end

  def working_branch
    train.working_branch
  end

  def new_branch_name
    starting_time.strftime("rel/#{train.display_name}/%d-%m-%Y")
  end

  def webhook_url
    if Rails.env.development?
      github_events_url(host: ENV['WEBHOOK_HOST_NAME'], train_id: train.id)
    else
      github_events_url(host: ENV['HOST_NAME'], train_id: train.id, protocol: 'https')
    end
  end
end

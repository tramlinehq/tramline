class Triggers::Deployment
  include Memery

  def self.call(step_run:, deployment: nil)
    new(step_run:, deployment:).call
  end

  def initialize(step_run:, deployment:)
    @step_run = step_run
    @deployment = deployment.presence || first_deployment
    @starting_time = Time.current
  end

  def call
    step_run
      .deployment_runs
      .create!(deployment:, scheduled_at: starting_time)
      .then { |deployment_run| dispatch_job!(deployment_run) }
  end

  private

  delegate :external?, :slack_integration?, :google_play_store_integration?, to: :deployment
  attr_reader :deployment, :step_run, :starting_time

  # FIXME: should we take a lock around this SR? what is someone double triggers the run?
  def dispatch_job!(deployment_run)
    if external?
      Rails.logger.info("External deployment, doing nothing...")
      deployment_run.release!
      return
    end

    if google_play_store_integration?
      Deployments::GooglePlayStore::Upload.perform_later(deployment_run.id)
    elsif slack_integration?
      Deployments::Slack.perform_later(deployment_run.id)
    end

    deployment_run.dispatch_job!
  end

  def first_deployment
    step_run.step.deployments.find_by(deployment_number: 1)
  end
end

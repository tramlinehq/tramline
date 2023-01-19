class Triggers::Deployment
  include Memery
  delegate :transaction, to: ::DeploymentRun

  def self.call(step_run:, deployment: nil)
    new(step_run:, deployment:).call
  end

  def initialize(step_run:, deployment:)
    @step_run = step_run
    @deployment = deployment.presence || first_deployment
    @starting_time = Time.current
  end

  def call
    transaction do
      step_run
        .deployment_runs
        .create!(deployment:, scheduled_at: starting_time)
        .dispatch_job!
    end
  end

  private

  attr_reader :deployment, :step_run, :starting_time

  def first_deployment
    step_run.step.deployments.find_by(deployment_number: 1)
  end
end

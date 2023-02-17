class Triggers::Deployment
  include Memery
  delegate :transaction, to: ::DeploymentRun

  def self.call(step_run:, deployment:)
    new(step_run:, deployment:).call
  end

  def initialize(step_run:, deployment:)
    @step_run = step_run
    @deployment = deployment
    @starting_time = Time.current
  end

  def call
    transaction do
      step_run
        .deployment_runs
        .create!(deployment:, scheduled_at: starting_time)
        .dispatch!
    end
  end

  private

  attr_reader :deployment, :step_run, :starting_time
end

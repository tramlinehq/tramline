class Deployments::Slack < ApplicationJob
  queue_as :high
  delegate :transaction, to: DeploymentRun
  MESSAGE = "A wild new release has appeared!"

  def perform(deployment_run_id)
    @deployment_run = DeploymentRun.find(deployment_run_id)
    return unless deployment.integration.slack_integration?

    @deployment_run.with_lock do
      # FIXME: this transaction can eventually be removed, just use Result objects
      transaction do
        push
        @deployment_run.complete!
      end
    end
  end

  def push
    provider.deploy!(channel, MESSAGE, :deployment_finished, {step_run: step_run})
  end

  def deployment
    @deployment_run.deployment
  end

  def step_run
    @deployment_run.step_run
  end

  def channel
    deployment.deployment_channel
  end

  def provider
    deployment.integration.providable
  end
end

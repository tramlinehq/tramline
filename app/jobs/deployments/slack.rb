class Deployments::Slack < ApplicationJob
  queue_as :high
  sidekiq_options retry: 0
  delegate :transaction, to: DeploymentRun

  def perform(deployment_run_id)
    deployment_run = DeploymentRun.find(deployment_run_id)
    deployment = deployment_run.deployment
    return unless deployment.integration.slack_integration?

    # FIXME: this transaction can eventually be removed, just use Result objects
    transaction do
      push(deployment, deployment_run.step_run)
      deployment_run.release!
    end
  end

  def push(deployment, step_run)
    train = step_run.train
    message = "A wild new release has appeared!"
    text_block = Notifiers::Slack::DeploymentFinished.render_json(step_run: step_run)
    channel = deployment.build_artifact_channel.values.first
    provider = deployment.integration.providable
    Triggers::Notification.dispatch!(train:, message:, text_block:, channel:, provider:)
  end
end

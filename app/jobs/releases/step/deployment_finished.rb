class Releases::Step::DeploymentFinished < ApplicationJob
  queue_as :high
  delegate :transaction, to: Releases::Step::Run

  def perform(step_run_id)
    step_run = Releases::Step::Run.find(step_run_id)
    return unless step_run.step.build_artifact_integration.eql?("SlackIntegration")

    train = step_run.train
    message = "A Wild new Release has appeared!"
    text_block = Notifiers::Slack::DeploymentFinished.render_json(step_run: step_run)
    channel = step_run.step.build_artifact_channel.values.first
    provider = step_run.step.app.slack_build_channel_provider

    # FIXME: this transaction can eventually be removed, just use Result objects
    transaction do
      Automatons::Notify.dispatch!(train:, message:, text_block:, channel:, provider:)
      step_run.mark_success!
    end
  end
end

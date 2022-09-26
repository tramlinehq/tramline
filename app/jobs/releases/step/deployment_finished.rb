class Releases::Step::DeploymentFinished < ApplicationJob
  queue_as :high
  sidekiq_options retry: false
  delegate :transaction, to: Releases::Step::Run

  def perform(step_run_id)
    step_run = Releases::Step::Run.find(step_run_id)
    step = step_run.step
    return unless step_run.step.build_artifact_integration.eql?("SlackIntegration")
    # FIXME: potential race condition here if a commit lands right here... . at this point...
    # ...and starts another run, but the release phase is triggered for an effectively stale run
    step_run.train_run.update!(status: Releases::Train::Run.statuses[:release_phase]) if step.last?

    train = step_run.train
    message = "A wild new release has appeared!"
    text_block = Notifiers::Slack::DeploymentFinished.render_json(step_run: step_run)
    channel = step_run.step.build_artifact_channel.values.first
    provider = step_run.step.app.slack_build_channel_provider

    # FIXME: this transaction can eventually be removed, just use Result objects
    transaction do
      Triggers::Notification.dispatch!(train:, message:, text_block:, channel:, provider:)
      step_run.finish!
    end
  end
end

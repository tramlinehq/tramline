class Releases::Step::PushToSlack < ApplicationJob
  queue_as :high

  def perform(step_run_id)
    step_run = Releases::Step::Run.find(step_run_id)
    return unless step_run.step.build_artifact_integration.eql?("SlackIntegration")

    Rails.logger.debug "Performing!"
    Rails.logger.debug step_run.step.build_artifact_channel
    Rails.logger.debug step_run.step.app.slack_build_channel_provider

    Automatons::Notify.dispatch!(
      train: step_run.train,
      message: "New Release!",
      text_block: Notifiers::Slack::DeploymentCompleted.render_json(step_run: step_run),
      channel: step_run.step.build_artifact_channel.values.first,
      provider: step_run.step.app.slack_build_channel_provider
    )

    Rails.logger.debug "Finished!"
  end
end

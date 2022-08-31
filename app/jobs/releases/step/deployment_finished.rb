class Releases::Step::DeploymentFinished < ApplicationJob
  queue_as :high

  def perform(step_run_id)
    step_run = Releases::Step::Run.find(step_run_id)
    return unless step_run.step.build_artifact_integration.eql?("SlackIntegration")

    Automatons::Notify.dispatch!(
      train: step_run.train,
      message: "New Release!",
      text_block: Notifiers::Slack::DeploymentFinished.render_json(step_run: step_run),
      channel: step_run.step.build_artifact_channel.values.first,
      provider: step_run.step.app.slack_build_channel_provider
    )
  end
end

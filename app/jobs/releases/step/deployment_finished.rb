class Releases::Step::DeploymentFinished < ApplicationJob
  queue_as :high
  delegate :transaction, to: ApplicationRecord

  def perform(step_run_id, should_promote = true)
    return unless should_promote
    step_run = Releases::Step::Run.find(step_run_id)
    return unless step_run.step.build_artifact_integration.eql?("SlackIntegration")

    transaction do
      Automatons::Notify.dispatch!(
        train: step_run.train,
        message: "New Release!",
        text_block: Notifiers::Slack::DeploymentFinished.render_json(step_run: step_run),
        channel: step_run.step.build_artifact_channel.values.first,
        provider: step_run.step.app.slack_build_channel_provider
      )

      step_run.mark_success!
      step_run.build_artifact.create_release_situation!(status: ReleaseSituation.statuses[:released])
    end
  end
end

class Deployments::Slack < ApplicationJob
  queue_as :high

  def perform(deployment_run_id)
    run = DeploymentRun.find(deployment_run_id)
    return unless run.slack_integration?
    run.push_to_slack!
  end
end

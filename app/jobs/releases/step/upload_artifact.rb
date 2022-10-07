class Releases::Step::UploadArtifact < ApplicationJob
  queue_as :high
  sidekiq_options retry: 0

  def perform(step_run_id, artifacts_url)
    step_run = Releases::Step::Run.find(step_run_id)

    begin
      stream = step_run.ci_cd_provider.download_stream(artifacts_url)
      BuildArtifact.new(step_run: step_run, generated_at: Time.current).save_zip!(stream)

      step_run.ready_to_deploy!

      if step_run.previous_run&.deployment_runs&.any?
        step_run.previous_run.deployment_runs.each do |deployment_run|
          Triggers::Deployment.call(deployment: deployment_run.deployment, step_run: step_run)
        end
      else
        Triggers::Deployment.call(step_run: step_run)
      end
    rescue => e
      Rails.logger.error(e)
      Sentry.capture_exception(e)
      step_run.fail_deploy! # FIXME: this should actually be upload_failed maybe?
    end
  end
end

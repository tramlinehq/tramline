class Releases::UploadArtifact < ApplicationJob
  queue_as :high

  def perform(step_run_id, artifacts_url)
    step_run = Releases::Step::Run.find(step_run_id)
    generated_at = Time.current # FIXME: this should be passed along from the CI workflow metadata

    begin
      step_run.get_build_artifact(artifacts_url).with_open do |artifact_stream|
        BuildArtifact.new(step_run: step_run, generated_at: generated_at).save_file!(artifact_stream)
      end

      step_run.ready_to_deploy!

      if step_run.previous_deployments.any?
        step_run.previous_deployments.each do |deployment|
          Triggers::Deployment.call(deployment: deployment, step_run: step_run)
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

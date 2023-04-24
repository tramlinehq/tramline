class Deployments::GoogleFirebase::UpdateUploadStatusJob
  include Sidekiq::Job
  extend Loggable
  extend Backoffable

  queue_as :high
  sidekiq_options retry: 21

  sidekiq_retry_in do |count, ex|
    if ex.is_a?(Deployments::GoogleFirebase::Release::UploadNotComplete)
      backoff_in(attempt: count, period: :minutes, type: :linear).to_i
    else
      elog(ex)
      :kill
    end
  end

  def perform(deployment_run_id, op_name)
    run = DeploymentRun.find(deployment_run_id)
    return unless run.google_firebase_integration?

    Deployments::GoogleFirebase::Release.update_upload_status!(run, op_name)
  end
end

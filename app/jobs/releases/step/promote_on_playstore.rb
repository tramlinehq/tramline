require "zip"

class Releases::Step::PromoteOnPlaystore < ApplicationJob
  queue_as :high
  delegate :transaction, to: Releases::Step::Run

  def perform(step_run_id)
    step_run = Releases::Step::Run.find(step_run_id)
    step_run.with_lock do
      step = step_run.step
      return unless step.build_artifact_integration.eql?("GooglePlayStoreIntegration")

      # FIXME: potential race condition here if a commit lands right here... . at this point...
      # ...and starts another run, but the release phase is triggered for an effectively stale run
      step_run.train_run.update!(status: Releases::Train::Run.statuses[:release_phase]) if step.last?

      package_name = step.app.bundle_identifier
      key = StringIO.new(step.deployment_provider.providable.json_key)
      release_version = step_run.train_run.release_version

      api = Installations::Google::PlayDeveloper::Api.new(package_name, key, release_version)
      api.promote(step.deployment_channel, step_run.build_number)
      raise api.errors if api.errors.present?
      step_run.mark_success!
    end
  end
end

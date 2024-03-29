class Releases::BuildAvailableNotificationJob < ApplicationJob
  include Loggable
  queue_as :high
  sidekiq_options retry: 2

  def perform(step_run_id, notification_params)
    step_run = StepRun.find(step_run_id)
    return unless step_run
    train = step_run.train
    build_artifact = step_run.build_artifact
    attachment_title = step_run.build_display_name
    attachment_name = build_artifact.get_filename

    build_artifact.with_open do |attachment|
      train.notify_with_attachment!("A new build is available!", :build_available, notification_params, attachment, attachment_title, attachment_name)
    end
  end
end

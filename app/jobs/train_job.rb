class KickoffTrainJob < ApplicationJob
  queue_as :high

  delegate :transaction, to: ActiveRecord::Base

  def perform(id)
    now = Time.current
    train = Releases::Train.find(id)

    return if train.inactive?
    return if train.steps.size < 1
    return if train.runs.size >= 1 && train.runs.last.was_run_at > now

    user = train.app.organization.users.first

    transaction do
      # start the train run (overarching run)
      code_name = RandomNameGenerator.flip_mode.compose
      train_run = train.runs.create!(
        scheduled_at: now,
        was_run_at: now,
        status: Releases::Train::Run.statuses[:on_track],
        code_name:)

      # start the first step run (because it runs as soon as the train kicks off)
      KickoffStepJob.perform_now(train_run.id, train.steps.first.id, user.id)

      # enq the subsequent train step runs at their designated times
      train.steps.drop(1).each do |step|
        KickoffStepJob.set(wait_until: now + step.run_after_duration).perform_later(train_run.id, step.id, user.id)
      end
    end
  end
end

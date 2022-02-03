class StepJob < ApplicationJob
  queue_as :high
  delegate :transaction, to: ActiveRecord::Base

  def perform(train_run_id, step_id, user_id)
    now = Time.current
    train_run = Releases::Train::Run.find(train_run_id)
    step = Releases::Step.find(step_id)

    # officially start the step
    step_run = step.runs.create!(
      train_run: train_run,
      scheduled_at: now,
      was_run_at: now,
      status: Releases::Step::Run.statuses[:on_track],
      current_user: Accounts::User.find(user_id)
    )

    step_run.automatons!
  end
end

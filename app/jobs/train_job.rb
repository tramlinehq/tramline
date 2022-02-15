class TrainJob < ApplicationJob
  queue_as :high
  sidekiq_options retry: false

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
      train_run = train.runs.create!(
        scheduled_at: now,
        was_run_at: now,
        status: Releases::Train::Run.statuses[:on_track],
        code_name: Haikunator.haikunate(100)
      )

      release_branch = train_run.release_branch
      message = "Created release branch: #{release_branch}.\nCI workflow started for: #{train_run.code_name}!"

      Automatons::Branch.dispatch!(train: train, branch: release_branch)
      Automatons::Notify.dispatch!(train: train, message: message)
      Automatons::Email.dispatch!(train: train, user: user)

      # start the first step run (because it runs as soon as the train kicks off)
      StepJob.perform_now(train_run.id, train.steps.first.id, user.id)

      # enq the subsequent train step runs at their designated times
      train.steps.drop(1).each do |step|
        StepJob.set(wait_until: now + step.run_after_duration).perform_later(train_run.id, step.id, user.id)
      end
    end
  end
end

class Releases::Step::Run < ApplicationRecord
  self.implicit_order_column = :was_run_at

  belongs_to :step, class_name: "Releases::Step", foreign_key: :train_step_id
  belongs_to :train_run, class_name: "Releases::Train::Run", foreign_key: :train_run_id
  has_many :integrations, through: :train

  enum status: { on_track: "on_track", halted: "halted", finished: "finished" }

  attr_accessor :current_user

  delegate :train, to: :step
  delegate :integrations, to: :train
  delegate :transaction, to: ActiveRecord::Base

  def automatons!
    transaction do
      release_branch = train_run.release_branch
      message = "Created release branch: #{release_branch}.\nCI workflow started for: #{train_run.code_name}!"

      if step.step_number <= 1
        Automatons::Branch.dispatch!(step: step, branch: release_branch)
        Automatons::Notify.dispatch!(message:, integration: notification_integration)
      end

      Automatons::Email.dispatch!(user: current_user)
      Automatons::Workflow.dispatch!(step: step, ref: release_branch)
    end
  end

  def wrap_up_run!
    self.status = Releases::Step::Run.statuses[:finished]

    if step.last?
      train_run.status = Releases::Train::Run.statuses[:finished]
      train_run.save!
    end

    save!
  end

  def notification_integration
    integrations.notification.first
  end
end

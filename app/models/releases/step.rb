class Releases::Step < ApplicationRecord
  has_paper_trail
  extend FriendlyId

  self.table_name = :train_steps
  self.implicit_order_column = :step_number

  belongs_to :train, class_name: "Releases::Train", inverse_of: :steps
  has_many :runs, class_name: "Releases::Step::Run", inverse_of: :step, foreign_key: :train_step_id

  delegate :app, to: :train

  enum status: {
    active: "active",
    inactive: "inactive"
  }

  friendly_id :name, use: :slugged

  before_validation :set_step_number
  validate :within_train_schedule
  after_initialize :set_default_status

  def set_step_number
    self.step_number = train.steps.maximum(:step_number).to_i + 1
  end

  def set_default_status
    self.status = Releases::Step.statuses[:active]
  end

  def first?
    train.steps.minimum(:step_number).to_i == step_number
  end

  def last?
    train.steps.maximum(:step_number).to_i == step_number
  end

  def absolute_run_after
    train
      .steps
      .where("step_number <= ?", step_number)
      .order(:step_number)
      .pluck(:run_after_duration)
      .sum
  end

  def next_run_at
    return if train.current_run.blank?
    train.current_run.last_run_step.was_run_at + run_after_duration
  end

  private

  def within_train_schedule
    unless (train.kickoff_at + absolute_run_after) < (train.kickoff_at + train.repeat_duration)
      errors.add(:run_after_duration, "Please ensure that all steps finish before the train ends.")
    end
  end
end

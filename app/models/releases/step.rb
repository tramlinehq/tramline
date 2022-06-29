class Releases::Step < ApplicationRecord
  has_paper_trail
  extend FriendlyId

  self.table_name = :train_steps
  self.implicit_order_column = :step_number

  belongs_to :train, class_name: "Releases::Train", inverse_of: :steps
  has_many :runs, class_name: "Releases::Step::Run", inverse_of: :step, foreign_key: :train_step_id
  has_many :sign_offs, foreign_key: :train_step_id
  has_many :sign_off_groups, through: :train
  has_one :app, through: :train

  delegate :app, to: :train

  enum status: {
    active: "active",
    inactive: "inactive"
  }

  friendly_id :name, use: :slugged

  before_validation :set_step_number
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

  def next
    train.steps.where('step_number > ?', step_number).first
  end
end

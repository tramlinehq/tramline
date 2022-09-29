class Releases::Step < ApplicationRecord
  has_paper_trail
  extend FriendlyId

  self.table_name = :train_steps
  self.implicit_order_column = :step_number

  belongs_to :train, class_name: "Releases::Train", inverse_of: :steps
  has_many :runs, class_name: "Releases::Step::Run", inverse_of: :step, foreign_key: :train_step_id, dependent: :destroy
  has_many :sign_offs, foreign_key: :train_step_id, inverse_of: :step, dependent: :destroy
  has_many :sign_off_groups, through: :train
  has_many :deployments, foreign_key: :train_step_id, inverse_of: :step, dependent: :destroy
  has_many :deployment_runs, through: :deployments, class_name: "DeploymentRun"
  has_one :app, through: :train

  validates :ci_cd_channel, presence: true, uniqueness: { scope: :train_id }
  validates :release_suffix, presence: true
  validates :release_suffix, format: {with: /\A[a-zA-Z\-_]+\z/, message: "only allows letters and underscore"}

  delegate :app, to: :train

  enum status: {
    active: "active",
    inactive: "inactive"
  }

  friendly_id :name, use: :slugged
  auto_strip_attributes :name, squish: true

  before_validation :set_step_number, if: :new_record?
  after_initialize :set_default_status, if: :new_record?

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
    train.steps.where("step_number > ?", step_number)&.first
  end

  def previous
    train.steps.where("step_number < ?", step_number).last
  end

  def startable?
    return false if train.inactive?
    return true if runs.empty? && first?
    return false if train.active_run.nil?
    return false if first?

    (train.active_run&.next_step == self) && (approved_previous_step? && previous.runs.last.success?)
  end

  def approved_previous_step?
    previous.runs.last.approval_approved?
  end

  def available_deployment_channels
    if external_deployment?
      [["External", {"external" => "external"}.to_json]]
    else
      app.integrations.build_channel.find_by(providable_type: build_artifact_integration).providable.channels
    end
  end

  def deployment_provider
    app.integrations.build_channel.find_by(providable_type: build_artifact_integration)
  end

  def deployment_channel
    build_artifact_channel.values.first
  end

  def external_deployment?
    build_artifact_integration == "external"
  end
end

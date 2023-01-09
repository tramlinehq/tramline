# == Schema Information
#
# Table name: train_steps
#
#  id                         :uuid             not null, primary key
#  build_artifact_channel     :json
#  build_artifact_integration :string
#  ci_cd_channel              :jsonb            not null, indexed => [train_id]
#  description                :string           not null
#  name                       :string           not null
#  release_suffix             :string           not null
#  slug                       :string
#  status                     :string           not null
#  step_number                :integer          default(0), not null, indexed => [train_id]
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  train_id                   :uuid             not null, indexed => [ci_cd_channel], indexed => [step_number], indexed
#
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

  validates :ci_cd_channel, presence: true, uniqueness: {scope: :train_id, message: "you have already used this in another step of this train!"}
  validates :release_suffix, presence: true
  validates :release_suffix, format: {with: /\A[a-zA-Z\-_]+\z/, message: "only allows letters and underscore"}
  validates :deployments, presence: true, on: :create
  validate :unique_deployments, on: :create
  validate :unique_store_deployments_per_train, on: :create

  after_initialize :set_default_status, if: :new_record?
  before_validation :set_step_number, if: :new_record?

  enum status: {
    active: "active",
    inactive: "inactive"
  }

  friendly_id :name, use: :slugged
  auto_strip_attributes :name, squish: true
  accepts_nested_attributes_for :deployments, allow_destroy: false, reject_if: :reject_deployments?

  delegate :app, to: :train

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

  private

  def reject_deployments?(attributes)
    attributes["build_artifact_channel"].blank? || !attributes["build_artifact_channel"].is_a?(Hash)
  end

  def unique_deployments
    duplicates =
      deployments
        .group_by { |deployment| deployment.values_at(:build_artifact_channel, :integration_id, :train_step_id) }
        .values
        .detect { |arr| arr.size > 1 }

    errors.add(:deployments, "should be designed to have unique providers and channels") if duplicates
  end

  def unique_store_deployments_per_train
    duplicates =
      deployments
        .filter(&:store?)
        .any? { |deployment| train.deployments.exists?(build_artifact_channel: deployment.build_artifact_channel, integration: deployment.integration) }

    errors.add(:deployments, "cannot have repeated store configurations across steps in the same train") if duplicates
  end
end

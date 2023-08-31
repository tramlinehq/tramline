# == Schema Information
#
# Table name: steps
#
#  id                  :uuid             not null, primary key
#  auto_deploy         :boolean          default(TRUE)
#  ci_cd_channel       :jsonb            not null, indexed => [release_platform_id]
#  description         :string           not null
#  kind                :string
#  name                :string           not null
#  release_suffix      :string
#  slug                :string
#  status              :string           not null
#  step_number         :integer          default(0), not null, indexed => [release_platform_id]
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  release_platform_id :uuid             not null, indexed => [ci_cd_channel], indexed, indexed => [step_number]
#
class Step < ApplicationRecord
  has_paper_trail
  extend FriendlyId

  self.implicit_order_column = :step_number

  belongs_to :release_platform, inverse_of: :steps
  has_many :step_runs, inverse_of: :step, dependent: :destroy
  has_many :deployments, -> { sequential }, inverse_of: :step, dependent: :destroy
  has_many :deployment_runs, through: :deployments

  validates :ci_cd_channel, presence: true, uniqueness: {scope: :release_platform_id, message: "you have already used this in another step of this train!"}
  validates :release_suffix, format: {with: /\A[a-zA-Z\-_]+\z/, message: "only allows letters and underscore"}, if: -> { release_suffix.present? }
  validates :deployments, presence: true, on: :create
  validate :unique_deployments, on: :create
  validate :unique_store_deployments_per_train, on: :create
  validate :auto_deployment_allowed, on: :create

  after_initialize :set_default_status, if: :new_record?
  before_validation :set_step_number, if: :new_record?

  enum status: {
    active: "active",
    inactive: "inactive"
  }

  enum kind: {
    review: "review",
    release: "release"
  }

  friendly_id :name, use: :slugged
  auto_strip_attributes :name, squish: true
  accepts_nested_attributes_for :deployments, allow_destroy: false, reject_if: :reject_deployments?

  delegate :app, :train, to: :release_platform
  delegate :android?, to: :app
  delegate :ci_cd_provider, :notify!, to: :train

  def set_step_number
    self.step_number = release_platform.steps.review.maximum(:step_number).to_i + 1
    release_platform.release_step&.update!(step_number: step_number.succ) if review?
  end

  def set_default_status
    self.status = Step.statuses[:active]
  end

  def first?
    release_platform.steps.minimum(:step_number).to_i == step_number
  end

  def last?
    release_platform.steps.maximum(:step_number).to_i == step_number
  end

  def next
    release_platform.steps.where("step_number > ?", step_number)&.first
  end

  def previous
    release_platform.steps.where("step_number < ?", step_number).last
  end

  def notification_params
    train.notification_params.merge(
      {
        step_type: kind.titleize,
        step_name: name
      }
    )
  end

  def has_production_deployment?
    deployments.any?(&:production_channel?)
  end

  private

  def reject_deployments?(attributes)
    attributes["build_artifact_channel"].blank? || !attributes["build_artifact_channel"].is_a?(Hash)
  end

  def unique_deployments
    duplicates =
      deployments
        .group_by { |deployment| deployment.values_at(:build_artifact_channel, :integration_id, :step_id) }
        .values
        .detect { |arr| arr.size > 1 }

    errors.add(:deployments, "should be designed to have unique providers and channels") if duplicates
  end

  def unique_store_deployments_per_train
    duplicates =
      deployments
        .filter(&:store?)
        .any? { |deployment| release_platform.deployments.exists?(build_artifact_channel: deployment.build_artifact_channel, integration: deployment.integration) }

    errors.add(:deployments, "cannot have repeated store configurations across steps in the same train") if duplicates
  end

  def auto_deployment_allowed
    errors.add(:auto_deploy, "cannot turn off auto deployment for review step") if review? && !auto_deploy?
  end
end

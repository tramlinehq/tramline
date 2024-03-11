# == Schema Information
#
# Table name: steps
#
#  id                          :uuid             not null, primary key
#  auto_deploy                 :boolean          default(TRUE)
#  build_artifact_name_pattern :string
#  ci_cd_channel               :jsonb            not null, indexed => [release_platform_id]
#  description                 :string           not null
#  discarded_at                :datetime         indexed
#  kind                        :string
#  name                        :string           not null
#  release_suffix              :string
#  slug                        :string
#  status                      :string           not null
#  step_number                 :integer          default(0), not null, indexed => [release_platform_id]
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  app_variant_id              :uuid
#  integration_id              :uuid             indexed
#  release_platform_id         :uuid             not null, indexed => [ci_cd_channel], indexed, indexed => [step_number]
#
class Step < ApplicationRecord
  has_paper_trail
  extend FriendlyId
  include Discard::Model

  self.implicit_order_column = :step_number

  belongs_to :release_platform, inverse_of: :steps
  belongs_to :app_variant, inverse_of: :steps, optional: true
  belongs_to :integration, optional: true
  has_many :step_runs, inverse_of: :step, dependent: :destroy
  has_many :deployments, -> { kept.sequential }, inverse_of: :step, dependent: :destroy
  has_many :all_deployments, -> { sequential }, class_name: "Deployment", inverse_of: :step, dependent: :destroy
  has_many :deployment_runs, through: :deployments
  validates :ci_cd_channel, presence: true, uniqueness: {scope: :release_platform_id, conditions: -> { kept }, message: "you have already used this in another step of this train!"}
  validates :release_suffix, format: {with: /\A[a-zA-Z\-_]+\z/, message: "only allows letters and underscore"}, if: -> { release_suffix.present? }
  validates :deployments, presence: true, on: :create
  validate :unique_deployments, on: :create
  validate :unique_store_deployments_per_train, on: :create
  validate :auto_deployment_allowed, on: :create

  after_initialize :set_default_status, if: :new_record?
  before_validation :set_step_number, if: :new_record?
  before_save -> { self.build_artifact_name_pattern = build_artifact_name_pattern.downcase }, if: -> { build_artifact_name_pattern.present? }
  after_create :set_ci_cd_provider

  enum status: {
    active: "active",
    inactive: "inactive"
  }

  enum kind: {
    review: "review",
    release: "release"
  }

  friendly_id :name, use: :slugged
  auto_strip_attributes :name, :build_artifact_name_pattern, squish: true
  accepts_nested_attributes_for :deployments, allow_destroy: false, reject_if: :reject_deployments?

  delegate :app, :train, to: :release_platform
  delegate :android?, to: :app
  delegate :notify!, to: :train

  def ci_cd_provider
    integration.providable
  end

  def set_ci_cd_provider
    update(integration: train.ci_cd_provider.integration)
  end

  def active_deployments_for(release, step_run = nil)
    # no release
    return deployments unless release

    # ongoing release
    return step_run.deployment_runs.map(&:deployment) if release.end_time.blank? && step_run&.success?
    return deployments if release.end_time.blank?

    # historical release only
    all_deployments
      .where("created_at <= ?", release.end_time)
      .where("discarded_at IS NULL OR discarded_at >= ?", release.end_time)
  end

  def suffixable?
    release_suffix.present? && release_platform.android?
  end

  def set_step_number
    all_steps = release_platform.all_steps

    if review?
      self.step_number = all_steps.review.maximum(:step_number).to_i + 1
      release_platform.release_step&.update!(step_number: step_number.succ)
    else
      self.step_number = all_steps.maximum(:step_number).to_i + 1
    end
  end

  def set_default_status
    self.status = Step.statuses[:active]
  end

  def manual_trigger_only?
    release? && train.manual_release? && release_platform.has_review_steps?
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

  def workflow_id
    ci_cd_channel["id"]
  end

  def workflow_name
    ci_cd_channel["name"]
  end

  def replicate(new_release_platform)
    new_step = dup
    new_step.release_platform = new_release_platform
    deployments.each { |deployment| deployment.replicate(new_step) }
    new_step.save!
  end

  def has_uploadables?
    deployments.any?(&:uploadable?)
  end

  def has_findables?
    deployments.any?(&:findable?)
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

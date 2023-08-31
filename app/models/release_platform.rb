# == Schema Information
#
# Table name: release_platforms
#
#  id                       :uuid             not null, primary key
#  branching_strategy       :string
#  description              :string
#  name                     :string           not null
#  platform                 :string
#  release_backmerge_branch :string
#  release_branch           :string
#  slug                     :string
#  status                   :string
#  version_current          :string
#  version_seeded_with      :string
#  working_branch           :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  app_id                   :uuid             not null, indexed
#  train_id                 :uuid
#  vcs_webhook_id           :string
#

class ReleasePlatform < ApplicationRecord
  has_paper_trail
  using RefinedString
  extend FriendlyId
  include Displayable

  # self.ignored_columns += %w[branching_strategy description release_backmerge_branch release_branch version_current version_seeded_with working_branch vcs_webhook_id status]

  belongs_to :app
  belongs_to :train

  has_many :release_platform_runs, inverse_of: :release_platform, dependent: :destroy
  has_many :steps, -> { order(:step_number) }, inverse_of: :release_platform, dependent: :destroy
  has_many :deployments, through: :steps

  enum platform: {android: "android", ios: "ios"}

  friendly_id :name, use: :slugged

  validate :ready?, on: :create

  delegate :ready?, to: :app
  delegate :integrations, to: :train

  def has_release_step?
    steps.release.any?
  end

  alias_method :startable?, :has_release_step?

  def has_production_deployment?
    release_step&.has_production_deployment?
  end

  def has_review_steps?
    steps.review.exists?
  end

  def release_step
    steps.release.first
  end

  def display_name
    name&.parameterize
  end

  def ordered_steps_until(step_number)
    steps.where("step_number <= ?", step_number).order(:step_number)
  end

  def in_creation?
    train.draft? && steps.release.none?
  end

  def valid_steps?
    steps.release.size == 1
  end

  def store_provider
    if platform == "ios"
      app.ios_store_provider
    elsif platform == "android"
      app.android_store_provider
    else
      raise ArgumentError, "invalid platform value"
    end
  end

  def build_channel_integrations
    integrations
      .build_channel
      .where(providable_type: Integration::ALLOWED_INTEGRATIONS_FOR_APP[platform][:build_channel])
  end
end

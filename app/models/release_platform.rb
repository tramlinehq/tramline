# == Schema Information
#
# Table name: release_platforms
#
#  id         :uuid             not null, primary key
#  name       :string           not null
#  platform   :string
#  slug       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  app_id     :uuid             not null, indexed
#  train_id   :uuid
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
  has_one :active_run, -> { pending_release }, class_name: "ReleasePlatformRun", inverse_of: :release_platform, dependent: :destroy
  has_many :steps, -> { order(:step_number) }, inverse_of: :release_platform, dependent: :destroy
  has_many :deployments, through: :steps

  enum platform: {android: "android", ios: "ios"}

  friendly_id :name, use: :slugged

  validate :ready?, on: :create

  delegate :ready?, to: :app

  def has_release_step?
    steps.release.any?
  end

  alias_method :startable?, :has_release_step?

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
    steps.release.none? && !steps.review.any?
  end

  def valid_steps?
    steps.release.size == 1
  end
end

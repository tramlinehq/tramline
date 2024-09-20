# == Schema Information
#
# Table name: release_platforms
#
#  id                       :uuid             not null, primary key
#  branching_strategy       :string
#  config                   :jsonb
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
  NATURAL_ORDER = Arel.sql("CASE WHEN platform = 'android' THEN 1 WHEN platform = 'ios' THEN 2 ELSE 3 END")

  belongs_to :app
  belongs_to :train
  has_one :platform_config, class_name: "Config::ReleasePlatform", dependent: :destroy
  has_many :release_health_rules, -> { kept }, dependent: :destroy, inverse_of: :release_platform
  has_many :all_release_health_rules, dependent: :destroy, inverse_of: :release_platform, class_name: "ReleaseHealthRule"
  has_many :release_platform_runs, inverse_of: :release_platform, dependent: :destroy
  has_many :steps, -> { kept.order(:step_number) }, inverse_of: :release_platform, dependent: :destroy
  has_many :all_steps, -> { order(:step_number) }, class_name: "Step", inverse_of: :release_platform, dependent: :destroy
  has_many :deployments, through: :steps

  scope :sequential, -> { order(NATURAL_ORDER) }

  enum :platform, {android: "android", ios: "ios"}

  friendly_id :name, use: :slugged

  validate :ready?, on: :create
  before_save :set_default_config, if: :new_record?

  delegate :integrations, :ci_cd_provider, to: :train
  delegate :ready?, :default_locale, to: :app

  def self.allowed_platforms
    {
      android: "Android",
      ios: "iOS"
    }.invert
  end

  def active_steps_for(release)
    # no release
    return steps unless release
    return steps if release.active?

    # historical release only
    all_steps
      .where(created_at: ..release.end_time)
      .where("discarded_at IS NULL OR discarded_at >= ?", release.end_time)
  end

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
    steps.where(step_number: ..step_number).order(:step_number)
  end

  def in_creation?
    train.draft? && steps.release.none?
  end

  def valid_steps?
    steps.release.size == 1
  end

  def store_provider
    if ios?
      app.ios_store_provider
    elsif android?
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

  def active_locales
    app.latest_external_apps[platform.to_sym]&.active_locales
  end

  def default_locale
    app.latest_external_apps[platform.to_sym]&.default_locale
  end

  private

  def set_default_config
    return if Rails.env.test?
    return if platform_config.present?

    ci_cd_channel = train.ci_cd_provider.workflows.first
    config_map = {
      workflows: {
        internal: nil,
        release_candidate: {
          kind: "release_candidate",
          name: ci_cd_channel[:name],
          id: ci_cd_channel[:id],
          artifact_name_pattern: nil
        }
      },
      internal_release: nil,
      beta_release: nil,
      production_release: andrdoid ? android_production_release_config : ios_production_release_config
    }

    self.platform_config = Config::ReleasePlatform.from_json(config_map)
  end

  def android_production_release_config
    {
      auto_promote: false,
      submissions: [
        {number: 1,
         submission_type: "PlayStoreSubmission",
         submission_config: GooglePlayStoreIntegration::PROD_CHANNEL,
         rollout_config: {enabled: true, stages: AppStoreIntegration::DEFAULT_PHASED_RELEASE_SEQUENCE},
         auto_promote: false}
      ]
    }
  end

  def ios_production_release_config
    {
      auto_promote: false,
      submissions: [
        {number: 1,
         submission_type: "AppStoreSubmission",
         submission_config: AppStoreIntegration::PROD_CHANNEL,
         rollout_config: {enabled: true, stages: AppStoreIntegration::DEFAULT_PHASED_RELEASE_SEQUENCE},
         auto_promote: false}
      ]
    }
  end
end

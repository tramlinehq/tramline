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

  self.ignored_columns += %w[branching_strategy description release_backmerge_branch release_branch version_current version_seeded_with working_branch vcs_webhook_id status config]

  NATURAL_ORDER = Arel.sql("CASE WHEN platform = 'android' THEN 1 WHEN platform = 'ios' THEN 2 ELSE 3 END")
  DEFAULT_PROD_RELEASE_CONFIG = {
    android: {
      auto_promote: false,
      submissions: [
        {number: 1,
         submission_type: "PlayStoreSubmission",
         submission_config: GooglePlayStoreIntegration::PROD_CHANNEL,
         rollout_config: {enabled: true, stages: AppStoreIntegration::DEFAULT_PHASED_RELEASE_SEQUENCE},
         auto_promote: false}
      ]
    },
    ios: {
      auto_promote: false,
      submissions: [
        {number: 1,
         submission_type: "AppStoreSubmission",
         submission_config: AppStoreIntegration::PROD_CHANNEL,
         rollout_config: {enabled: true, stages: AppStoreIntegration::DEFAULT_PHASED_RELEASE_SEQUENCE},
         auto_promote: false}
      ]
    }
  }.with_indifferent_access

  belongs_to :app
  belongs_to :train
  has_one :platform_config, class_name: "Config::ReleasePlatform", dependent: :destroy
  has_many :release_health_rules, -> { kept }, dependent: :destroy, inverse_of: :release_platform
  has_many :all_release_health_rules, dependent: :destroy, inverse_of: :release_platform, class_name: "ReleaseHealthRule"
  has_many :release_platform_runs, inverse_of: :release_platform, dependent: :destroy

  scope :sequential, -> { order(NATURAL_ORDER) }

  enum :platform, {android: "android", ios: "ios"}

  friendly_id :name, use: :slugged

  validate :ready?, on: :create
  after_create :set_default_config

  delegate :integrations, :ci_cd_provider, to: :train
  delegate :ready?, :default_locale, to: :app
  delegate :has_restricted_public_channels?, to: :platform_config

  def self.allowed_platforms
    {
      android: "Android",
      ios: "iOS"
    }.invert
  end

  def display_name
    name&.parameterize
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

  def production_ready?
    store_provider.present?
  end

  def active_locales
    app.latest_external_apps[platform.to_sym]&.active_locales
  end

  def default_locale
    app.latest_external_apps[platform.to_sym]&.default_locale
  end

  def production_submission_type
    DEFAULT_PROD_RELEASE_CONFIG[platform.to_sym][:submissions].first[:submission_type] if production_ready?
  end

  private

  # setup production if the store integrations are added
  # otherwise use the first build channel integration and setup beta releases
  def set_default_config
    return if Rails.env.test?
    return if platform_config.present?

    rc_ci_cd_channel = train.workflows.first || {}
    base_config_map = {
      release_platform: self,
      workflows: {
        internal: nil,
        release_candidate: {
          kind: "release_candidate",
          name: rc_ci_cd_channel[:name],
          id: rc_ci_cd_channel[:id],
          artifact_name_pattern: nil
        }
      },
      internal_release: nil,
      beta_release: {
        auto_promote: false,
        submissions: []
      }
    }

    if production_ready?
      base_config_map[:production_release] = DEFAULT_PROD_RELEASE_CONFIG[platform.to_sym]
      base_config_map[:production_release][:submissions].each do |submission|
        submission[:integrable_id] = app.id
        submission[:integrable_type] = "App"
      end
    end

    if base_config_map[:production_release].nil?
      providable = app.integrations.build_channels_for_platform(platform).first.providable
      providable_type = providable.class
      submission_type = Integration::INTEGRATIONS_TO_PRE_PROD_SUBMISSIONS[platform.to_sym][providable_type].to_s
      submission_config = providable.pick_default_beta_channel
      submissions = [
        {
          number: 1,
          submission_type:,
          submission_config:,
          auto_promote: false,
          integrable_id: app.id,
          integrable_type: "App"
        }
      ]
      base_config_map[:beta_release][:submissions] = submissions
    end

    config_obj = Config::ReleasePlatform.from_json(base_config_map)
    Rails.logger.debug { "Errors in default config for #{name}: #{config_obj.errors.full_messages}" } unless config_obj.valid?
    self.platform_config = config_obj
  end
end

# == Schema Information
#
# Table name: app_configs
#
#  id                      :uuid             not null, primary key
#  bitbucket_workspace     :string
#  bugsnag_android_config  :jsonb
#  bugsnag_ios_config      :jsonb
#  code_repository         :json
#  firebase_android_config :jsonb
#  firebase_ios_config     :jsonb
#  jira_config             :jsonb            not null
#  linear_config           :jsonb            not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  app_id                  :uuid             not null, indexed
#  bitrise_project_id      :jsonb
#
class AppConfig < ApplicationRecord
  has_paper_trail
  include AppConfigurable

  PLATFORM_AWARE_CONFIG_SCHEMA = Rails.root.join("config/schema/platform_aware_integration_config.json")
  self.ignored_columns += %w[bugsnag_project_id firebase_crashlytics_android_config firebase_crashlytics_ios_config notification_channel ci_cd_workflows]

  belongs_to :app
  has_many :variants, class_name: "AppVariant", dependent: :destroy

  attr_accessor :bugsnag_ios_release_stage, :bugsnag_android_release_stage, :bugsnag_ios_project_id, :bugsnag_android_project_id

  # TODO: migrate validations to the appropriate integrations
  validates :firebase_ios_config,
    allow_blank: true,
    json: {message: ->(errors) { errors }, schema: PLATFORM_AWARE_CONFIG_SCHEMA}
  validates :firebase_android_config,
    allow_blank: true,
    json: {message: ->(errors) { errors }, schema: PLATFORM_AWARE_CONFIG_SCHEMA}
  validate :jira_release_filters, if: -> { jira_config&.dig("release_filters").present? }
  validate :linear_release_filters, if: -> { linear_config&.dig("release_filters").present? }

  after_initialize :set_bugsnag_config, if: :persisted?

  def bugsnag_project(platform)
    app.monitoring_provider.project(platform)
  end

  def bugsnag_release_stage(platform)
    app.monitoring_provider.release_stage(platform)
  end

  def ci_cd_workflows
    super&.map(&:with_indifferent_access)
  end

  def disconnect!(integration)
    if integration.version_control?
      self.code_repository = nil
    elsif integration.ci_cd?
      self.bitrise_project_id = nil
    end

    save!
  end

  private

  def set_bugsnag_config
    monitoring_provider = app.monitoring_provider
    self.bugsnag_ios_release_stage = monitoring_provider.ios_release_stage
    self.bugsnag_ios_project_id = monitoring_provider.ios_project_id
    self.bugsnag_android_release_stage = monitoring_provider.android_release_stage
    self.bugsnag_android_project_id = monitoring_provider.android_project_id
  end

  def firebase_ready?
    return true unless app.firebase_connected?
    firebase_build_channel = app.integrations.firebase_build_channel_provider
    configs_ready?(firebase_build_channel.ios_config, firebase_build_channel.android_config)
  end

  def bitrise_ready?
    return true unless app.bitrise_connected?
    app.ci_cd_provider&.project_config&.fetch("id", nil).present?
  end

  def bugsnag_ready?
    return true unless app.bugsnag_connected?
    monitoring_provider = app.monitoring_provider
    configs_ready?(monitoring_provider.ios_config, monitoring_provider.android_config)
  end

  def configs_ready?(ios, android)
    return ios.present? if app.ios?
    return android.present? if app.android?
    ios.present? && android.present? if app.cross_platform?
  end

  def project_management_ready?
    return false if app.integrations.project_management.blank?

    jira = app.integrations.project_management.find(&:jira_integration?)&.providable
    linear = app.integrations.project_management.find(&:linear_integration?)&.providable

    if jira
      return jira.project_config.present? &&
          jira.project_config["selected_projects"].present? &&
          jira.project_config["selected_projects"].any? &&
          jira.project_config["project_configs"].present?
    end

    if linear
      return linear.project_config.present? &&
          linear.project_config["selected_teams"].present? &&
          linear.project_config["selected_teams"].any? &&
          linear.project_config["team_configs"].present?
    end

    false
  end

  def jira_release_filters
    jira_config["release_filters"].each do |filter|
      unless filter.is_a?(Hash) && JiraIntegration::VALID_FILTER_TYPES.include?(filter["type"]) && filter["value"].present?
        errors.add(:jira_config, "release filters must contain valid type and value")
      end
    end
  end

  def linear_release_filters
    linear_config["release_filters"].each do |filter|
      unless filter.is_a?(Hash) && LinearIntegration::VALID_FILTER_TYPES.include?(filter["type"]) && filter["value"].present?
        errors.add(:linear_config, "release filters must contain valid type and value")
      end
    end
  end
end

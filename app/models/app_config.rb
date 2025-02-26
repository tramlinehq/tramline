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

  validates :firebase_ios_config,
    allow_blank: true,
    json: {message: ->(errors) { errors }, schema: PLATFORM_AWARE_CONFIG_SCHEMA}
  validates :firebase_android_config,
    allow_blank: true,
    json: {message: ->(errors) { errors }, schema: PLATFORM_AWARE_CONFIG_SCHEMA}
  validate :jira_release_filters, if: -> { jira_config&.dig("release_filters").present? }

  after_initialize :set_bugsnag_config, if: :persisted?

  def ready?
    further_setup_by_category?
      .values
      .pluck(:ready)
      .all?
  end

  def code_repository_name
    code_repository&.fetch("full_name", nil)
  end

  def code_repo_url
    code_repository&.fetch("repo_url", nil)
  end

  def code_repo_namespace
    code_repository&.fetch("namespace", nil)
  end

  def code_repo_name_only
    code_repository&.fetch("name", nil)
  end

  def bitrise_project
    bitrise_project_id&.fetch("id", nil)
  end

  def further_setup_by_category?
    integrations = app.integrations.connected
    categories = {}.with_indifferent_access

    if integrations.version_control.present?
      categories[:version_control] = {
        further_setup: integrations.version_control.any?(&:further_setup?),
        ready: code_repository.present?
      }
    end

    if integrations.ci_cd.present?
      categories[:ci_cd] = {
        further_setup: integrations.ci_cd.any?(&:further_setup?),
        ready: bitrise_ready?
      }
    end

    if integrations.build_channel.present?
      categories[:build_channel] = {
        further_setup: integrations.build_channel.map(&:providable).any?(&:further_setup?),
        ready: firebase_ready?
      }
    end

    if integrations.monitoring.present?
      categories[:monitoring] = {
        further_setup: integrations.monitoring.any?(&:further_setup?),
        ready: bugsnag_ready?
      }
    end

    if integrations.project_management.present?
      categories[:project_management] = {
        further_setup: integrations.project_management.map(&:providable).any?(&:further_setup?),
        ready: project_management_ready?
      }
    end

    categories
  end

  def bugsnag_project(platform)
    case platform
    when "android" then bugsnag_android_config["project_id"]
    when "ios" then bugsnag_ios_config["project_id"]
    else
      raise ArgumentError, INVALID_PLATFORM_ERROR
    end
  end

  def bugsnag_release_stage(platform)
    case platform
    when "android" then bugsnag_android_config["release_stage"]
    when "ios" then bugsnag_ios_config["release_stage"]
    else
      raise ArgumentError, INVALID_PLATFORM_ERROR
    end
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
    self.bugsnag_ios_release_stage = bugsnag_ios_config&.fetch("release_stage", nil)
    self.bugsnag_ios_project_id = bugsnag_ios_config&.fetch("project_id", nil)
    self.bugsnag_android_release_stage = bugsnag_android_config&.fetch("release_stage", nil)
    self.bugsnag_android_project_id = bugsnag_android_config&.fetch("project_id", nil)
  end

  def firebase_ready?
    return true unless app.firebase_connected?
    configs_ready?(firebase_ios_config, firebase_android_config)
  end

  def bitrise_ready?
    return true unless app.bitrise_connected?
    bitrise_project.present?
  end

  def bugsnag_ready?
    return true unless app.bugsnag_connected?
    configs_ready?(bugsnag_ios_config, bugsnag_android_config)
  end

  def configs_ready?(ios, android)
    return ios.present? if app.ios?
    return android.present? if app.android?
    ios.present? && android.present? if app.cross_platform?
  end

  def project_management_ready?
    return false if app.integrations.project_management.blank?

    jira = app.integrations.project_management.find(&:jira_integration?)&.providable
    return false unless jira

    jira_config.present? &&
      jira_config["selected_projects"].present? &&
      jira_config["selected_projects"].any? &&
      jira_config["project_configs"].present?
  end

  def jira_release_filters
    jira_config["release_filters"].each do |filter|
      unless filter.is_a?(Hash) && JiraIntegration::VALID_FILTER_TYPES.include?(filter["type"]) && filter["value"].present?
        errors.add(:jira_config, "release filters must contain valid type and value")
      end
    end
  end
end

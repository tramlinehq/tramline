# == Schema Information
#
# Table name: app_configs
#
#  id                      :uuid             not null, primary key
#  code_repository         :json
#  firebase_android_config :jsonb
#  firebase_ios_config     :jsonb
#  notification_channel    :json
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  app_id                  :uuid             not null, indexed
#  bitrise_project_id      :jsonb
#  bugsnag_project_id      :jsonb
#
class AppConfig < ApplicationRecord
  has_paper_trail
  include Notifiable
  include PlatformAwareness

  MINIMUM_REQUIRED_CONFIG = %i[code_repository]
  PLATFORM_AWARE_CONFIG_SCHEMA = Rails.root.join("config/schema/platform_aware_integration_config.json")

  belongs_to :app
  has_many :variants, class_name: "AppVariant", dependent: :destroy

  validates :firebase_ios_config,
    allow_blank: true,
    json: {message: ->(errors) { errors }, schema: PLATFORM_AWARE_CONFIG_SCHEMA}
  validates :firebase_android_config,
    allow_blank: true,
    json: {message: ->(errors) { errors }, schema: PLATFORM_AWARE_CONFIG_SCHEMA}

  def ready?
    MINIMUM_REQUIRED_CONFIG.all? { |config| public_send(config).present? } && firebase_ready? && bitrise_ready? && bugsnag_ready?
  end

  def code_repository_name
    return if code_repository.blank?
    code_repository["full_name"]
  end

  def code_repo_url
    code_repository["repo_url"]
  end

  def code_repo_namespace
    code_repository["namespace"]
  end

  def code_repo_name_only
    code_repository["name"]
  end

  def bitrise_project
    bitrise_project_id&.fetch("id", nil)
  end

  def bugsnag_project
    bugsnag_project_id&.fetch("id", nil)
  end

  def further_build_channel_setup?
    app.integrations.build_channel.map(&:providable).any?(&:further_build_channel_setup?)
  end

  def further_ci_cd_setup?
    app.integrations.ci_cd_provider.further_setup?
  end

  def further_monitoring_setup?
    app.integrations.monitoring_provider&.further_setup?
  end

  def firebase_app(platform, variant: nil)
    return variant.pick_firebase_app_id(platform) if variant&.in?(variants)
    pick_firebase_app_id(platform)
  end

  private

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
    bugsnag_project.present?
  end

  def configs_ready?(ios, android)
    return ios.present? if app.ios?
    return android.present? if app.android?
    ios.present? && android.present? if app.cross_platform?
  end
end

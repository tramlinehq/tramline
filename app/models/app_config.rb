# == Schema Information
#
# Table name: app_configs
#
#  id                      :uuid             not null, primary key
#  bitrise_android_config  :jsonb
#  bitrise_ios_config      :jsonb
#  code_repository         :json
#  firebase_android_config :jsonb
#  firebase_ios_config     :jsonb
#  notification_channel    :json
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  app_id                  :uuid             not null, indexed
#  bitrise_project_id      :jsonb
#
class AppConfig < ApplicationRecord
  has_paper_trail
  include Notifiable

  MINIMUM_REQUIRED_CONFIG = %i[code_repository]

  PLATFORM_AWARE_CONFIG_SCHEMA = Rails.root.join("config/schema/platform_aware_integration_config.json")

  belongs_to :app

  validates :firebase_ios_config,
    allow_blank: true,
    json: {message: ->(errors) { errors }, schema: PLATFORM_AWARE_CONFIG_SCHEMA}
  validates :firebase_android_config,
    allow_blank: true,
    json: {message: ->(errors) { errors }, schema: PLATFORM_AWARE_CONFIG_SCHEMA}
  validates :bitrise_ios_config,
    allow_blank: true,
    json: {message: ->(errors) { errors }, schema: PLATFORM_AWARE_CONFIG_SCHEMA}
  validates :bitrise_android_config,
    allow_blank: true,
    json: {message: ->(errors) { errors }, schema: PLATFORM_AWARE_CONFIG_SCHEMA}

  def ready?
    MINIMUM_REQUIRED_CONFIG.all? { |config| public_send(config).present? } && firebase_ready? && bitrise_ready?
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

  def bitrise_project
    bitrise_project_id.fetch("id", nil)
  end

  def further_build_channel_setup?
    app.integrations.build_channel.map(&:providable).any?(&:further_build_channel_setup?)
  end

  def platform_aware_config(ios, android)
    if app.android?
      {android: android}
    elsif app.ios?
      {ios: ios}
    elsif app.cross_platform?
      {ios: ios, android: android}
    end
  end

  private

  def firebase_ready?
    return true if app.integrations.google_firebase_integrations.none?
    configs_ready?(firebase_ios_config, firebase_android_config)
  end

  def bitrise_ready?
    return true if app.integrations.bitrise_integrations.none?
    configs_ready?(bitrise_ios_config, bitrise_android_config)
  end

  def configs_ready?(ios, android)
    return ios.present? if app.ios?
    return android.present? if app.android?
    ios.present? && android.present? if app.cross_platform?
  end
end

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
#
class AppConfig < ApplicationRecord
  has_paper_trail

  MINIMUM_REQUIRED_CONFIG = %i[code_repository]
  FIREBASE_CONFIG_SCHEMA = Rails.root.join("config/schema/firebase_config.json")

  belongs_to :app

  validates :firebase_ios_config,
    allow_blank: true,
    json: {message: ->(errors) { errors }, schema: FIREBASE_CONFIG_SCHEMA}
  validates :firebase_android_config,
    allow_blank: true,
    json: {message: ->(errors) { errors }, schema: FIREBASE_CONFIG_SCHEMA}

  def ready?
    MINIMUM_REQUIRED_CONFIG.all? { |config| public_send(config).present? } && firebase_ready?
  end

  def notification_channel_id
    return if notification_channel.blank?
    notification_channel["id"]
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

  def setup_firebase_config
    return {} if app.integrations.google_firebase_integrations.none?

    ios_apps = app.integrations.firebase_build_channel_provider.list_apps(platform: "ios")
    android_apps = app.integrations.firebase_build_channel_provider.list_apps(platform: "android")

    if app.android?
      {android: android_apps}
    elsif app.ios?
      {ios: ios_apps}
    elsif app.cross_platform?
      {ios: ios_apps, android: android_apps}
    end
  end

  private

  def firebase_ready?
    return true if app.integrations.google_firebase_integrations.none?
    return firebase_ios_config.present? if app.ios?
    return firebase_android_config.present? if app.android?
    firebase_ios_config.present? && firebase_android_config.present? if app.cross_platform?
  end
end

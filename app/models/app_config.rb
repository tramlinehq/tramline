# == Schema Information
#
# Table name: app_configs
#
#  id                       :uuid             not null, primary key
#  bitrise_platform_config  :jsonb
#  code_repository          :json
#  firebase_platform_config :jsonb
#  notification_channel     :json
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  app_id                   :uuid             not null, indexed
#  project_id               :jsonb
#
class AppConfig < ApplicationRecord
  has_paper_trail

  MINIMUM_REQUIRED_CONFIG = %i[code_repository]

  belongs_to :app

  validates :bitrise_platform_config,
    allow_blank: true,
    json: {message: ->(errors) { errors },
           schema: -> {
                     Rails.root.join("config/schema/",
                       app.cross_platform? ? "bitrise_platform_config.json" : "bitrise_config.json")
                   }}
  validates :firebase_platform_config,
    allow_blank: true,
    json: {message: ->(errors) { errors },
           schema: -> {
                     Rails.root.join("config/schema/",
                       app.cross_platform? ? "firebase_platform_config.json" : "firebase_config.json")
                   }}

  def ready?
    MINIMUM_REQUIRED_CONFIG.all? { |config| public_send(config).present? }
  end

  def code_repository_name
    return if code_repository.blank?
    code_repository["full_name"]
  end

  def notification_channel_id
    return if notification_channel.blank?
    notification_channel["id"]
  end

  def code_repo_namespace
    code_repository["namespace"]
  end

  def code_repo_url
    code_repository["repo_url"]
  end

  def project
    project_id.fetch("id", nil)
  end
end

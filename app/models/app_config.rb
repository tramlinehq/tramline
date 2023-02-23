# == Schema Information
#
# Table name: app_configs
#
#  id                   :uuid             not null, primary key
#  code_repository      :json
#  notification_channel :json
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  app_id               :uuid             not null, indexed
#  project_id           :jsonb
#
class AppConfig < ApplicationRecord
  has_paper_trail

  MINIMUM_REQUIRED_CONFIG = %i[code_repository]

  belongs_to :app

  def ready?
    MINIMUM_REQUIRED_CONFIG.all? { |config| public_send(config).present? }
  end

  def code_repository_name
    return unless code_repository
    code_repository["full_name"]
  end

  def notification_channel_id
    return unless notification_channel
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

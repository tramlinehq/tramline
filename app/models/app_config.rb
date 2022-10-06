class AppConfig < ApplicationRecord
  has_paper_trail

  belongs_to :app
  self.ignored_columns = [:working_branch]

  MINIMAL_REQUIRED_CONFIG = %i[code_repository notification_channel]

  def ready?
    MINIMAL_REQUIRED_CONFIG.all? { |config| public_send(config).present? }
  end

  def code_repository_name
    return unless code_repository
    code_repository.values.first
  end

  def notification_channel_name
    return unless notification_channel
    notification_channel.values.first
  end

  def code_repository_organization_name_hack
    code_repository_name.partition("/").first
  end

  def project
    project_id.keys.first
  end
end

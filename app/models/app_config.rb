class AppConfig < ApplicationRecord
  has_paper_trail

  belongs_to :app
  self.ignored_columns = [:working_branch]

  MINIMAL_REQUIRED_CONFIG = [:code_repository, :notification_channel]

  def ready?
    MINIMAL_REQUIRED_CONFIG.all? { |config| public_send(config).present? }
  end
end

class AppConfig < ApplicationRecord
  has_paper_trail

  belongs_to :app

  MINIMAL_REQUIRED_CONFIG = [:code_repository, :notification_channel, :working_branch].freeze

  def ready?
    MINIMAL_REQUIRED_CONFIG.all? { |config| public_send(config).present? }
  end
end

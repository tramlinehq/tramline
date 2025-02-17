module Supportable
  extend ActiveSupport::Concern

  included do
    if Rails.production?
      after_action :prepare_support_chat_shutdown, only: [:destroy]
      after_action :support_chat_shutdown, only: [:new]
    end
  end

  protected

  def prepare_support_chat_shutdown
    Chatwoot::ShutdownHelper.prepare_chatwoot_shutdown(session)
  end

  def support_chat_shutdown
    Chatwoot::ShutdownHelper.chatwoot_shutdown(session, cookies, request.domain)
  end
end

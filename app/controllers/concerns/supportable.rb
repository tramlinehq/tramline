module Supportable
  protected

  def prepare_support_chat_shutdown
    Chatwoot::ShutdownHelper.prepare_chatwoot_shutdown(session)
  end

  def support_chat_shutdown
    Chatwoot::ShutdownHelper.chatwoot_shutdown(session, cookies, request.domain)
  end
end

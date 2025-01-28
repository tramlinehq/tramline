module Chatwoot
  module ShutdownHelper
    # This helper allows to erase cookies when a user logs out of an application
    # Do not use before a redirect_to because it will not clear the cookies on a redirection
    def self.chatwoot_shutdown_helper(cookies, domain = nil)
      nil_session = {value: nil, expires: 1.day.ago}
      nil_session = nil_session.merge(domain: domain) unless domain.nil? || domain == "localhost"
      chatwoot_token = ENV["CHATWOOT_WEBSITE_TOKEN"]
      session_cookie = "cw_user_#{chatwoot_token}"
      conversation_cookie = "cw_conversation"

      if cookies.is_a?(ActionDispatch::Cookies::CookieJar)
        cookies[session_cookie] = nil_session
        cookies[conversation_cookie] = nil_session
      else
        controller = cookies
        controller.response.delete_cookie(session_cookie, nil_session)
        controller.response.delete_cookie(conversation_cookie, nil_session)
      end

      Rails.logger.debug { "Chatwoot: session cleared" }
    rescue
      Rails.logger.debug { "Chatwoot: shutdown failed" }
      nil
    end

    def self.prepare_chatwoot_shutdown(session)
      session[:perform_chatwoot_shutdown] = true
    end

    def self.chatwoot_shutdown(session, cookies, domain = nil)
      if session[:perform_chatwoot_shutdown]
        session.delete(:perform_chatwoot_shutdown)
        chatwoot_shutdown_helper(cookies, domain)
      end
    end
  end
end

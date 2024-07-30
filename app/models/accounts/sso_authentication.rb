# == Schema Information
#
# Table name: sso_authentications
#
#  id               :uuid             not null, primary key
#  email            :string           default(""), not null, indexed
#  logout_time      :datetime
#  sso_created_time :datetime
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  login_id         :string           not null, indexed
#
class Accounts::SsoAuthentication < ApplicationRecord
  include Linkable

  has_one :user_authentication, as: :authenticatable, dependent: :destroy
  has_one :user, through: :user_authentication

  class << self
    def start_sign_in(tenant)
      client.saml_sign_in(tenant: tenant, redirect_url:)
    end

    def finish_sign_in(code)
      GitHub::Result.new { parse_jwt(client.saml_exchange_token(code)) }
    end

    def validate_or_refresh_session(session_token, refresh_token)
      GitHub::Result.new { parse_jwt(client.validate_and_refresh_session(session_token:, refresh_token:)) }
    end

    def parse_jwt(jwt)
      params = {}
      session = jwt[Descope::Mixins::Common::SESSION_TOKEN_NAME]
      refresh = jwt[Descope::Mixins::Common::REFRESH_SESSION_TOKEN_NAME]
      session_token = session&.fetch("jwt", nil)
      refresh_token = refresh&.fetch("jwt", nil)
      user_email = session&.fetch("email", nil)
      first_name = session&.fetch("first_name", nil)
      last_name = session&.fetch("last_name", nil)
      full_name = [first_name, last_name].join(" ").squish.presence || user_email
      preferred_name = session&.fetch("name", nil) || first_name
      login_id = session&.fetch("sub", nil)

      params[:session_token] = session_token
      params[:user_email] = user_email
      params[:user_full_name] = full_name
      params[:user_preferred_name] = preferred_name
      params[:login_id] = login_id
      params[:refresh_token] = refresh_token if refresh_token.present?
      params
    end

    def client
      Rails.application.config.descope_client
    end

    def redirect_url
      return if Rails.env.test?
      sso_saml_redeem_url(link_params(port: nil))
    end
  end

  def add(invite, full_name, preferred_name)
    build_user(full_name:, preferred_name:)
    user.memberships.new(organization: invite.organization, role: invite.role)
    invite.mark_accepted(user) if save
  end
end

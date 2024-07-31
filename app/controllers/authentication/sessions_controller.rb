class Authentication::SessionsController < ApplicationController
  include Authenticatable
  before_action :authenticate_sso_request!, if: :login_by_sso?

  def root
    if current_user
      if current_user.admin?
        redirect_to authenticated_admin_root_path
      else
        redirect_to authenticated_root_path
      end
    else
      redirect_to new_email_authentication_session_path
    end
  end
end

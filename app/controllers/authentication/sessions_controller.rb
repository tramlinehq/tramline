class Authentication::SessionsController < Devise::SessionsController
  include MetadataAwareness

  before_action :set_confirmed_email, only: [:new]
  after_action :prepare_intercom_shutdown, only: [:destroy]
  after_action :intercom_shutdown, only: [:new]
  after_action :track_login, only: [:create]

  def new
    super
  end

  def destroy
    super
  end

  def after_sign_in_path_for(resource)
    stored_location = stored_location_for(resource)
    if stored_location&.include? new_authentication_invite_confirmation_path
      return root_path
    end

    stored_location || root_path
  end

  protected

  def prepare_intercom_shutdown
    IntercomRails::ShutdownHelper.prepare_intercom_shutdown(session)
  end

  def intercom_shutdown
    IntercomRails::ShutdownHelper.intercom_shutdown(session, cookies, request.domain)
  end

  def set_confirmed_email
    @confirmed_email = params[:confirmed_email].presence || nil
  end

  def track_login
    SiteAnalytics.track(current_user, current_organization, device, "Login")
  end
end

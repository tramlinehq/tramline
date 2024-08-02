class Authentication::Email::SessionsController < Devise::SessionsController
  include Authenticatable

  before_action :skip_authentication, only: [:new, :create]
  before_action :set_confirmed_email, only: [:new]
  after_action :prepare_intercom_shutdown, only: [:destroy]
  after_action :intercom_shutdown, only: [:new]
  after_action :track_login, only: [:create]

  def new
    super
  end

  def create
    super
  end

  def destroy
    super
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
    SiteAnalytics.track(current_user, current_organization, device, "Login", {email: true})
  end
end

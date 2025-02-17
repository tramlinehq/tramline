class Authentication::Email::SessionsController < Devise::SessionsController
  include Authenticatable
  include Supportable

  before_action :skip_authentication, only: [:new, :create]
  before_action :set_confirmed_email, only: [:new]
  after_action :prepare_support_chat_shutdown, only: [:destroy]
  after_action :support_chat_shutdown, only: [:new]
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

  def set_confirmed_email
    @confirmed_email = params[:confirmed_email].presence || nil
  end

  def track_login
    SiteAnalytics.track(current_user, current_organization, device, "Login", {email: true})
  end
end

class Authentication::Email::PasswordsController < Devise::PasswordsController
  EmailAuth = Accounts::EmailAuthentication
  include Exceptionable
  include Authenticatable

  before_action :skip_authentication, only: [:new, :create]
  before_action :ensure_valid_token, only: [:edit]

  def new = super

  def edit = super

  def create = super

  private

  def ensure_valid_token
    original_token = params[:reset_password_token]
    reset_password_token = Devise.token_generator&.digest(self, :reset_password_token, original_token)

    email_auth = EmailAuth.find_or_initialize_with_errors([:reset_password_token], reset_password_token:)
    if !email_auth.persisted? || !email_auth.reset_password_period_valid?
      redirect_to new_email_authentication_password_path, alert: "Password reset link no longer valid; please request a new link."
    end
  end
end

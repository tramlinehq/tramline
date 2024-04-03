class Authentication::PasswordsController < Devise::PasswordsController
  include ExceptionHandler
  before_action :ensure_valid_token, only: [:edit]


  private

  def ensure_valid_token
    original_token = params[:reset_password_token]
    reset_password_token = Devise.token_generator&.digest(self, :reset_password_token, original_token)

    user = Accounts::User.find_or_initialize_with_errors([:reset_password_token], reset_password_token: reset_password_token)
    if !user.persisted? || !user.reset_password_period_valid?
      redirect_to new_user_password_path, alert: "Password reset link no longer valid; please request a new link."
    end
  end
end

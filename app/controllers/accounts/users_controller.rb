class Accounts::UsersController < SignedInApplicationController
  before_action :set_user, only: %i[edit update]

  def edit
  end

  def update
    if @user.update(parsed_user_params)
      redirect_to edit_accounts_user_path, notice: "Account was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = current_user
  end

  def parsed_user_params
    user_params.merge(memberships_params)
  end

  def user_params
    params
      .require(:accounts_user)
      .permit(:full_name, :preferred_name, :github_login)
  end

  def memberships_params
    params
      .require(:accounts_user)
      .permit(memberships_attributes: [:id, :team_id])
  end
end

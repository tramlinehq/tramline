class Accounts::UsersController < SignedInApplicationController
  before_action :set_user, only: %i[edit update update_user_role]
  before_action :set_organization, only: %i[update_user_role]

  def edit
  end

  def update
    if @user.update(parsed_user_params)
      redirect_to edit_accounts_user_path, notice: "Account was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def update_user_role
    email = params[:email]
    member = Accounts::User.find_via_email(email)

    if member.nil?
      redirect_to accounts_organization_teams_path(@current_organization), alert: "User #{email} not found" and return
    end

    if @user.id == member.id
      redirect_to accounts_organization_teams_path(@current_organization), alert: "User #{email} cannot change their own role." and return
    end

    current_organization_id = @current_organization.id

    organization = Accounts::Organization.find(current_organization_id)
    membership = member.memberships.find_by(organization: organization)

    if membership.nil?
      redirect_to accounts_organization_teams_path(@current_organization), alert: "User #{email} memberships not found" and return
    end

    if membership.update(role: params[:role])
      redirect_to accounts_organization_teams_path(@current_organization), notice: "#{email} role was successfully updated to #{params[:role]}"
    else
      redirect_to accounts_organization_teams_path(@current_organization), alert: "Updating #{email} role failed" and return
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

  def set_organization
    @current_organization = current_organization
  end
end

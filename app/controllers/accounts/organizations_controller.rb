class Accounts::OrganizationsController < SignedInApplicationController
  before_action :require_write_access!, only: %i[edit teams update remove_icon]
  before_action :set_organization, only: %i[edit update remove_icon]
  before_action :require_organization_write_access!, only: %i[update remove_icon]
  before_action :ensure_valid_icon, only: %i[update]

  def edit
    @tab_configuration = [
      [1, "Settings", edit_accounts_organization_path(@organization), "cog.svg"],
      [2, "Team", teams_accounts_organization_path(@organization), "user_cog.svg"]
    ]
  end

  def update
    if @organization.update(organization_params)
      redirect_to edit_accounts_organization_path(@organization), notice: "Organization was updated."
    else
      redirect_to edit_accounts_organization_path(@organization),
        flash: {error: "#{@organization.errors.full_messages.to_sentence}."}
    end
  end

  def remove_icon
    @organization.icon.purge_later if @organization.icon.attached?
    redirect_to edit_accounts_organization_path(@organization), notice: "Icon removed."
  end

  def teams
    @tab_configuration = [
      [1, "Settings", edit_accounts_organization_path(current_organization), "cog.svg"],
      [2, "Team", teams_accounts_organization_path(current_organization), "user_cog.svg"]
    ]
    @teams = current_organization.teams
    @users = current_organization.members
    @invited_users = current_organization.pending_invites
  end

  def rotate_api_key
    if @organization.rotate_api_key
      redirect_to root_path, notice: "API Updated"
    else
      redirect_to root_path, alert: "There was an error: #{@organization.errors.full_messages.to_sentence}"
    end
  end

  def switch
    cookies["current_organization"] = {value: params[:id], expires: 30.days}
    session[:active_organization] = params[:id]
    redirect_to :root
  end

  private

  def set_organization
    @organization = current_user.organizations.friendly.find(params[:id])
  end

  # require_write_access! only checks the role in the current organization,
  # so also check it for the organization that is actually being changed
  def require_organization_write_access!
    raise NotAuthorizedError unless current_user.writer_for?(@organization)
  end

  def organization_params
    params.require(:accounts_organization).permit(:icon)
  end

  def ensure_valid_icon
    if icon_params_errors.present?
      redirect_to edit_accounts_organization_path(@organization), flash: {error: icon_params_errors.first}
    end
  end

  def icon_params_errors
    @icon_params_errors ||= Validators::IconValidator.validate(organization_params[:icon]).errors
  end
end

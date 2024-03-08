class Accounts::OrganizationsController < SignedInApplicationController
  before_action :require_write_access!, only: %i[edit]

  def edit
    @organization = current_user.organizations.friendly.find(params[:id])
    @tab_configuration = [
      [1, "Settings", edit_accounts_organization_path(@organization), "v2/cog.svg"],
      [2, "Team", teams_accounts_organization_path(@organization), "v2/user_cog.svg"]
    ]
  end

  def teams
    @tab_configuration = [
      [1, "Settings", edit_accounts_organization_path(current_organization), "v2/cog.svg"],
      [2, "Team", teams_accounts_organization_path(current_organization), "v2/user_cog.svg"]
    ]
    @teams = current_organization.teams
    @users = current_organization.users.includes(:invitations)
    @invited_users = current_organization.invites.includes(:sender).not_accepted
  end

  def rotate_api_key
    if @organization.rotate_api_key
      redirect_to root_path, notice: "API Updated"
    else
      redirect_to root_path, alert: "There was an error: #{@organization.errors.full_messages.to_sentence}"
    end
  end

  def switch
    session[:active_organization] = params[:id]
    redirect_to :root
  end
end

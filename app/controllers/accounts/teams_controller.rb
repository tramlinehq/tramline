class Accounts::TeamsController < SignedInApplicationController
  def show
    @tab_configuration = [
      [1, "Settings", edit_accounts_organization_path(current_organization), "v2/cog.svg"],
      [2, "Team", accounts_organization_team_path(current_organization), "v2/user_cog.svg"]
    ]
    @teams = current_organization.teams
    @users = current_organization.users.includes(:invitations)
    @invited_users = current_organization.invites.includes(:sender).not_accepted
  end
end

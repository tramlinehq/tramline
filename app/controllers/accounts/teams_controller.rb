class Accounts::TeamsController < SignedInApplicationController
  def show
    @tab_configuration = [
      [1, "Settings", edit_accounts_organization_path(current_organization), "v2/cog.svg"],
      [2, "Team", accounts_organization_team_path(current_organization), "v2/user_cog.svg"]
    ]
    @team = current_organization.users
    @teams = current_organization.teams
    @invited_team = current_user.sent_invites.where(organization: current_organization).not_accepted
  end
end

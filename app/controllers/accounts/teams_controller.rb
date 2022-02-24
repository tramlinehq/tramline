class Accounts::TeamsController < SignedInApplicationController
  def show
    @team = current_organization.users
    @invited_team = current_user.sent_invites
  end
end

class Accounts::TeamsController < SignedInApplicationController
  def show
    @team = current_organization.users
    @invited_team = current_user.sent_invites.not_accepted
  end
end

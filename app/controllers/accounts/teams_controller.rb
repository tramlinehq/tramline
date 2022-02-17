class Accounts::TeamsController < SignedInApplicationController
  def show
    @team = current_organization.users
  end
end

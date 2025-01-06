# Invitation scenarios:
#
# |------------+-----------------------------------+-----------------------------------+--------------------------------------------|
# | scenario   | new user                          | existing user                     | existing but different user                |
# |------------+-----------------------------------+-----------------------------------+--------------------------------------------|
# | logged in  | ask to logout from home page      | accept and move on                | ask to log out from invite acceptance page |
# | logged out | sign up (with notice) and move on | accept and sign in (with  notice) | -                                          |
# |------------+-----------------------------------+-----------------------------------+--------------------------------------------|

class Accounts::InvitationsController < SignedInApplicationController
  before_action :require_write_access!, only: %i[create destroy]
  before_action :set_organization, only: [:create]

  def create
    @invite = Accounts::Invite.new(invite_params)
    @invite.sender = current_user

    if @invite.make
      redirect_to accounts_organization_teams_path(current_organization),
        notice: "Sent an invite to #{@invite.email}!"
    else
      redirect_to accounts_organization_teams_path(current_organization),
        flash: {error: @invite.errors.full_messages.to_sentence}
    end
  end

  def destroy
    @invite = current_organization.pending_invites.find_by(id: params[:id])

    if @invite&.destroy
      redirect_to accounts_organization_teams_path(current_organization),
        notice: "Invitation to #{@invite.email} has been cancelled"
    else
      redirect_to accounts_organization_teams_path(current_organization),
        flash: {error: "Could not cancel the invitation."}
    end
  end

  protected

  def invite_params
    params.require(:accounts_invite).permit(:email, :organization_id, :role)
  end

  def set_organization
    @organization = Accounts::Organization.find(invite_params[:organization_id])
  end
end

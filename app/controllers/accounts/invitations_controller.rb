# Invitation scenarios:
#
# |------------+-----------------------------------+-----------------------------------+--------------------------------------------|
# | scenario   | new user                          | existing user                     | existing but different user                |
# |------------+-----------------------------------+-----------------------------------+--------------------------------------------|
# | logged in  | ask to logout from home page      | accept and move on                | ask to log out from invite acceptance page |
# | logged out | sign up (with notice) and move on | accept and sign in (with  notice) | -                                          |
# |------------+-----------------------------------+-----------------------------------+--------------------------------------------|

class Accounts::InvitationsController < SignedInApplicationController
  before_action :require_write_access!, only: %i[create]

  def create
    @invite = Accounts::Invite.new(invite_params)
    @invite.sender = current_user

    if @invite.save
      begin
        if @invite.recipient.present?
          InvitationMailer.existing_user(@invite).deliver
        else
          InvitationMailer.new_user(@invite).deliver
        end
      rescue Postmark::ApiInputError
        flash[:error] = "Sorry, there was a delivery error while sending the invite!"
        redirect_to accounts_organization_team_path(current_organization)
      end

      redirect_to accounts_organization_team_path(current_organization),
        notice: "Sent an invite to #{@invite.email}!"
    else
      redirect_to accounts_organization_team_path(current_organization),
        notice: "Failed to send an invite to #{@invite.email}!"
    end
  end

  protected

  def invite_params
    params.require(:accounts_invite).permit(:email, :organization_id, :role)
  end
end

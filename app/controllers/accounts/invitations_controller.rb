class Accounts::InvitationsController < SignedInApplicationController
  def new
    @invite = Accounts::Invite.new(sender: current_user, organization: current_organization)
  end

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
        render :new, status: :unprocessable_entity
      end

      redirect_to accounts_organization_team_path(current_organization),
                  notice: "Sent an invite to #{@invite.email}!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  protected

  def invite_params
    params.require(:accounts_invite).permit(:email, :organization_id, :role)
  end
end

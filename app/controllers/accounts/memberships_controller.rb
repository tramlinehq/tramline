class Accounts::MembershipsController < SignedInApplicationController
  before_action :require_write_access!, only: %i[destroy]

  def destroy
    @membership = current_organization.memberships.find_by(id: params[:id])

    unless helpers.can_current_user_remove_member?(@membership.user)
      redirect_to teams_accounts_organization_path(current_organization),
                  flash: { error: "You don't have permission to remove this member" }
      return
    end

    if @membership.discarded?
      redirect_to teams_accounts_organization_path(current_organization),
                  flash: { error: "Member was already removed" }
    elsif @membership.discard
      puts "MembershipsController inside foo destroy"
      redirect_to teams_accounts_organization_path(current_organization),
                  notice: "Member #{@membership.user.email} has been removed"
    else
      redirect_to teams_accounts_organization_path(current_organization),
                  flash: {error: "#{@membership.errors.full_messages.to_sentence}"}
    end
  end
end

class Accounts::OrganizationsController < SignedInApplicationController
  def index
    @organizations = current_user.organizations
  end

  def switch
    session[:active_organization] = params[:id]
    redirect_to :root
  end
end

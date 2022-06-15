class Accounts::SignOffGroupsController < SignedInApplicationController
  def edit
    @organization = Accounts::Organization.friendly.find(params[:organization_id])
    @app = App.includes(sign_off_groups: :members).friendly.find(params[:app_id])
    @organization_members = @organization.users.map { |u| [u.full_name, u.id] }
  end

  def update
    organization = Accounts::Organization.friendly.find(params[:organization_id])
    app = App.friendly.find(params[:app_id])
    if app.update(sign_off_groups_attributes)
      redirect_to edit_accounts_organization_app_sign_off_groups_path(organization, app), notice: 'Sign off groups updated.'
    else
      render :edit, flash: { error: app.errors.full_messages.join(', ') }
    end
  end

  def sign_off_groups_attributes
    params.require(:app).permit(sign_off_groups_attributes: [:id, :name, :_destroy, { member_ids: [] }])
  end
end

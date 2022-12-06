class SignOffGroupsController < SignedInApplicationController
  before_action :require_write_access!, only: %i[edit update]

  def edit
    @app = current_organization.apps.includes(sign_off_groups: :members).friendly.find(params[:app_id])
    @organization_members = current_organization.users.map { |u| [u.full_name, u.id] }
  end

  def update
    app = current_organization.apps.friendly.find(params[:app_id])

    if app.update(sign_off_groups_attributes)
      redirect_to app_sign_off_groups_path(app), notice: "Sign off groups updated."
    else
      render :edit, flash: {error: app.errors.full_messages.join(", ")}
    end
  end

  private

  def sign_off_groups_attributes
    params.require(:app).permit(sign_off_groups_attributes: [:id, :name, :_destroy, {member_ids: []}])
  end
end

class Accounts::CustomStoragesController < Accounts::BaseController
  def edit
    @organization = current_organization
    @custom_storage = @organization.custom_storage || @organization.build_custom_storage
  end

  def update
    @organization = current_organization
    @custom_storage = @organization.custom_storage || @organization.build_custom_storage
    if @custom_storage.update(custom_storage_params)
      redirect_to edit_accounts_organization_path(@organization), notice: "Custom storage updated."
    else
      render :edit
    end
  end

  private

  def custom_storage_params
    creds = params.require(:accounts_custom_storage).permit(:bucket, :project_id, :credentials)
    creds[:credentials] = JSON.parse(creds[:credentials]) if creds[:credentials].is_a?(String)
    creds
  end
end

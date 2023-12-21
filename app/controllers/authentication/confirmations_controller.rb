class Authentication::ConfirmationsController < Devise::ConfirmationsController
  def show
    self.resource = resource_class.confirm_by_token(params[:confirmation_token])

    yield resource if block_given?

    if resource.errors.empty?
      set_flash_message!(:notice, :confirmed)
      SiteAnalytics.track(resource, resource.organizations.first, DeviceDetector.new(request.user_agent), "Email Confirmation")
    elsif resource.confirmed?
      set_flash_message!(:notice, :already_confirmed)
    else
      set_flash_message!(:error, :could_not_confirm)
    end

    respond_with_navigational(resource) { redirect_to after_confirmation_path_for(resource_name, resource) }
  end

  protected

  def after_confirmation_path_for(_resource_name, resource)
    if signed_in?(resource_name)
      signed_in_root_path(resource)
    else
      new_user_session_path(confirmed_email: resource&.email)
    end
  end
end

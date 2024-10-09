class Authentication::Email::ConfirmationsController < Devise::ConfirmationsController
  def show
    self.resource = resource_class.confirm_by_token(params[:confirmation_token])

    yield resource if block_given?

    if resource.errors.empty?
      set_flash_message!(:notice, :confirmed)
      identify_confirmation(resource, request)
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
      new_email_authentication_session_path(confirmed_email: resource&.email)
    end
  end

  def identify_confirmation(resource, request)
    SiteAnalytics.track(resource.user, resource.organization, DeviceDetector.new(request.user_agent), "Email Confirmation")
  end
end

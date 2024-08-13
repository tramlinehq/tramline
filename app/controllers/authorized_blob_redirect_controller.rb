class AuthorizedBlobRedirectController < ActiveStorage::Blobs::RedirectController
  include Authenticatable
  before_action :authenticate_sso_request!, if: :sso_authentication_signed_in?

  def show
    if unauthorized?
      render plain: "Access denied. Please login to continue.", status: :forbidden
      return
    end

    super
  end

  def unauthorized?
    return true if current_user.blank?
    !current_user.access_to_blob?(blob_signed_id)
  end

  def blob_signed_id
    params[:signed_id]
  end

  private

  def current_user
    @current_user ||= (current_email_authentication&.user || @current_sso_user)
  end
end

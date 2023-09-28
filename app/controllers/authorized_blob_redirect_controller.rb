class AuthorizedBlobRedirectController < ActiveStorage::Blobs::RedirectController
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
end

class Api::V1::AppsController < ApiController
  def show
    head :not_found and return if app.blank?
    render json: {latest: latest_store_version}, status: :ok
  end

  private

  def app
    @app ||=
      authorized_organization.apps.where(bundle_identifier: app_param)
        .or(authorized_organization.apps.where(slug: app_param)).sole
  end

  def latest_store_version
    app
      .latest_computed_store_version
      .map { |v| {version: v.first, build: v.second, created_at: v.third} }
  end

  def app_param
    params.require(:app_id)
  end
end

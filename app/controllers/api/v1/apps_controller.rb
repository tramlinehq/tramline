class Api::V1::AppsController < ApiController
  def show
    head :not_found and return if app.blank?
    render json: {latest: latest_store_version}, status: :ok
  end

  private

  def app
    @app ||= authorized_organization.apps.where(slug: app_param).sole
  end

  def latest_store_version
    app.latest_store_step_run
      &.then { |sr| {version: sr.first, build: sr.second, created_at: sr.third, platform: sr.fourth} }
  end

  def app_param
    params.require(:app_id)
  end
end

class Api::V1::AppsController < ApiController
  def show
    render json: {latest: latest_store_version}, status: :ok
  end

  private

  def app
    @app ||= authorized_organization.apps.where(slug: app_param).sole
  end

  def latest_store_version
    app.latest_store_step_runs.map(&:release_info).group_by { _1[:platform] }
  end

  def app_param
    params.require(:app_id)
  end
end

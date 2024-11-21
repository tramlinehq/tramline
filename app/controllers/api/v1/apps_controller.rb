class Api::V1::AppsController < ApiController
  def show
    render json: {latest: latest_store_version}, status: :ok
  end

  private

  def app
    @app ||= authorized_organization.apps.where(slug: app_param).sole
  end

  def latest_store_version
    if app.production_store_rollouts.none?
      return app.latest_store_step_runs.map(&:release_info).group_by { _1[:platform] }
    end

    app.production_store_rollouts
      .group_by(&:platform)
      .transform_values { |rollouts| rollouts.max_by(&:updated_at) }
      .transform_values(&:release_info)
  end

  def app_param
    params.require(:app_id)
  end
end

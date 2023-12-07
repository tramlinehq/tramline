class Api::V1::BuildsController < ApiController
  def external_metadata
    step_run = app.step_runs.where(build_number: build_params[:version_code], build_version: build_params[:version_name]).sole
    external_build_metadata = ExternalBuild.find_or_initialize_by(step_run:)
    new_metadata = external_build_metadata.update_or_insert!(build_params[:external_metadata].map(&:to_h))

    if new_metadata.errors.present?
      render json: {error: new_metadata.errors}, status: :unprocessable_entity
    else
      render json: {external_build: new_metadata}, status: :ok
    end
  end

  private

  def app
    @app ||= authorized_organization.apps.where(slug: build_params[:app_id]).sole
  end

  def build_params
    params.permit(
      :app_id,
      :version_name,
      :version_code,
      external_metadata: [
        :identifier,
        :name,
        :description,
        :value,
        :type,
        :unit
      ]
    )
  end
end

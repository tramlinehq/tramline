class Api::V1::WorkflowRunsController < ApiController
  def update_build_number
    return render_externally_managed_error unless workflow_run.app.build_number_managed_externally?

    workflow_run.update_build_number_from_api!(build_number_param)

    render json: {
      workflow_run: {
        id: workflow_run.id,
        build_number: workflow_run.build.build_number
      }
    }, status: :ok
  end

  private

  def workflow_run
    @workflow_run ||= WorkflowRun
      .joins(release_platform_run: {release: {train: :app}})
      .where(apps: {organization_id: authorized_organization.id})
      .find(params[:id])
  end

  def build_number_param
    params.require(:build_number)
  end

  def render_externally_managed_error
    render json: {error: "Build numbers are managed internally for this app"}, status: :unprocessable_entity
  end
end

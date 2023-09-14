class Api::V1::ReleasesController < ApiController
  def show
    render json: {releases: all_versions}, status: :ok
  end

  private

  def release
    @release ||=
      authorized_organization.releases.where(branch_name: release_param)
        .or(authorized_organization.releases.where(id: release_param)).sole
  end

  def all_versions
    release
      .all_completed_step_runs
      .map { |run| run.slice(:build_version, :build_number, :updated_at, :platform) }
  end

  def release_param
    params.require(:release_id)
  end
end

class Api::V1::ReleasesController < ApiController
  def show
    head :not_found and return if release.blank?
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
      .all_completed_versions
      .map { |v| {version: v.first, build: v.second, created_at: v.third} }
  end

  def release_param
    params.require(:release_id)
  end
end

class Api::V1::ReleasesController < ApiController
  def show
    head(:not_found) and return if all_versions.blank?
    render json: {releases: all_versions}, status: :ok
  end

  private

  def all_versions
    releases
      .flat_map { |release| release.is_v2? ? release.production_store_rollouts.flat_map(&:release_info) : release.all_store_step_runs&.map(&:release_info) }
      .then { |store_releases| store_releases.group_by { _1[:platform] } }
  end

  def releases
    @release ||=
      authorized_organization
        .releases
        .where(branch_name: release_param)
        .or(authorized_organization.releases.where(id: release_param))
  end

  def release_param
    params.require(:release_id)
  end
end

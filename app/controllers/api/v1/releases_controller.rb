class Api::V1::ReleasesController < ApiController
  def show
    head(:not_found) and return if all_versions.blank?
    render json: {releases: all_versions}, status: :ok
  end

  private

  def all_versions
    releases
      .flat_map { |release| release.production_store_rollouts.reorder(:updated_at).flat_map(&:release_info) }
      .then { |store_releases| store_releases.group_by { _1[:platform] } }
  end

  def releases
    @release ||=
      authorized_organization
        .releases
        .where(branch_name: release_param)
        .or(authorized_organization.releases.where(id: release_param))
        .or(authorized_organization.releases.where(slug: release_param))
  end

  def release_param
    params.require(:release_id)
  end
end

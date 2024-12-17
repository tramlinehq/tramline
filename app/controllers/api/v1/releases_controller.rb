class Api::V1::ReleasesController < ApiController
  def show
    head(:not_found) and return if all_versions.blank?
    render json: {releases: all_versions}, status: :ok
  end

  private

  def all_versions
    store_releases = releases.flat_map do |release|
      if release.is_v2?
        release
          .production_store_rollouts
          .reorder(:updated_at)
          .flat_map(&:release_info)
      else
        release
          .all_store_step_runs
          &.map(&:release_info)
      end
    end

    store_releases.group_by { |sr| sr[:platform] }
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

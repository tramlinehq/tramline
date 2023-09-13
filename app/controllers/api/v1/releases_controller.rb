class Api::V1::ReleasesController < ApiController
  def show
    head :not_found and return if release.blank?
    render json: {versions: all_versions}, status: :ok
  end

  private

  def release
    @release ||= Release.where(branch_name: release_param).or(Release.where(id: release_param)).sole
  end

  def all_versions
    release
      .all_completed_versions
      .map { |v| {version: v[:build_version], build: v[:build_number], created_at: v[:created_at]} }
  end

  def release_param
    params.require(:release_id)
  end
end

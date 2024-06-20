class StoreRolloutsController < SignedInApplicationController
  before_action :require_write_access!
  before_action :set_release
  before_action :set_release_platform
  before_action :set_release_platform_run

  private

  def set_release
    @release = Release.friendly.find(params[:release_id])
  end

  def set_release_platform
    @release_platform = @release.release_platforms.friendly.find_by(platform: params[:platform_id])
  end

  def set_release_platform_run
    @release_platform_run = @release.release_platform_runs.find_by(release_platform: @release_platform)
  end

  def set_store_rollout
    @store_rollout = @release_platform_run.store_rollouts.find_by(id: params[:id])
  end
end

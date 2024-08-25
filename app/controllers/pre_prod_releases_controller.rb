class PreProdReleasesController < SignedInApplicationController
  before_action :require_write_access!
  before_action :set_pre_prod_release
  before_action :set_app

  def changes_since_previous
  end

  def set_pre_prod_release
    @pre_prod_release = PreProdRelease.includes(release_platform_run: [release_platform: :app]).find(params[:id])
  end

  def set_app
    @app = @pre_prod_release.release_platform_run.app
  end
end

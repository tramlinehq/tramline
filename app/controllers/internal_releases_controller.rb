class InternalReleasesController < SignedInApplicationController
  before_action :require_write_access!
  before_action :set_pre_prod_release, only: %i[changes_since_previous]
  before_action :set_app, only: %i[changes_since_previous]

  def index
  end

  def create
    raise NotImplementedError
  end

  def changes_since_previous
  end

  def default_params
    params.require(:pre_prod_release).permit(:build_id, :commit_id)
  end

  def set_app
    @app = @pre_prod_release.release_platform_run.app
  end

  def set_pre_prod_release
    @pre_prod_release = PreProdRelease.includes(release_platform_run: [release_platform: :app]).find(params[:id])
  end
end

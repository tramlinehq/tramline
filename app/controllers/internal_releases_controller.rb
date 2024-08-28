class InternalReleasesController < SignedInApplicationController
  include Tabbable

  def index
    live_release!
    @app = @release.app
  end

  def default_params
    params.require(:pre_prod_release).permit(:build_id, :commit_id)
  end
end

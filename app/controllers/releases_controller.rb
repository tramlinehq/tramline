class ReleasesController < SignedInApplicationController
  before_action :set_release, only: [:show, :destroy]
  def create
    @app = current_organization.apps.friendly.find(params[:app_id])
    @train = @app.trains.friendly.find(params[:train_id])
    response = Services::TriggerRelease.call(@train)
    if response.success
      redirect_to live_release_app_train_releases_path(@app, @train), notice: "Train successfully started"
    else
      redirect_back fallback_location: root_path, flash: {error: response.body}
    end
  end

  def show
    @train = @release.train
    @app = @train.app
  end

  def live_release
    @app = current_organization.apps.friendly.find(params[:app_id])
    @train = @app.trains.friendly.find(params[:train_id])
    @release = @train.current_run
    if @release
      render :show
    else
      redirect_back fallback_location: root_path, notice: "No release in progress" unless @release
    end
  end

  def destroy
    @release.update(status: "finished")
    redirect_to app_train_path(@release.train.app, @release.train), notice: "Release marked as finished"
  end

  private

  def set_release
    @release = Releases::Train::Run.joins(train: :app).where(apps: {organization: current_organization}).find(params[:id])
  end
end

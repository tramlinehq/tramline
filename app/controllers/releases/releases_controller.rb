class Releases::ReleasesController < SignedInApplicationController
  def create
    @app = current_organization.apps.friendly.find(params[:app_id])
    @train = @app.trains.friendly.find(params[:train_id])
    Services::TriggerRelease.call(@train)
    redirect_back fallback_location: root_path, notice: "Train successfully started"
  end

  def show
    @release = Releases::Train::Run.find(params[:id])
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
    @release = Releases::Train::Run.find(params[:id])
    @release.update(status: "finished")
    redirect_back fallback_location: root_path, notice: "Release is marked as finished"
  end
end

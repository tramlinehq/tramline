class Accounts::Releases::ReleasesController < SignedInApplicationController
  before_action :set_release, only: [:show, :destroy]
  def create
    @app = current_organization.apps.friendly.find(params[:app_id])
    @train = @app.trains.friendly.find(params[:train_id])
    Services::TriggerRelease.call(@train)
    redirect_back fallback_location: root_path, notice: "Train successfully started"
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
    redirect_back fallback_location: root_path, notice: "Release is marked as finished"
  end

  private

  def set_release
    @release = Releases::Train::Run.joins(train: :app).where(apps: {organization: current_organization}).find(params[:id])
  end
end

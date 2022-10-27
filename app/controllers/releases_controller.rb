class ReleasesController < SignedInApplicationController
  before_action :set_release, only: [:show, :timeline, :destroy]

  def create
    @app = current_organization.apps.friendly.find(params[:app_id])
    @train = @app.trains.friendly.find(params[:train_id])

    response = Triggers::Release.call(@train)

    if response.success
      redirect_to live_release_path, notice: "A new release has started successfully."
    else
      redirect_back fallback_location: root_path, flash: {error: response.body}
    end
  end

  def show
    @train = @release.train
    @app = @train.app
    @pre_release_prs = @release.pull_requests.pre_release
    @post_release_prs = @release.pull_requests.post_release
  end

  def timeline
    @train = @release.train
    @app = @train.app
    @events = @release.events
  end

  def live_release
    @app = current_organization.apps.friendly.find(params[:app_id])
    @train = @app.trains.friendly.find(params[:train_id])
    @release = @train.active_run

    if @release
      render :show
    else
      redirect_back fallback_location: root_path, notice: "No release in progress." unless @release
    end
  end

  def destroy
    @release.update(status: "finished")
    redirect_to app_train_path(@release.train.app, @release.train), notice: "Release marked as finished."
  end

  def post_release
    @release = Releases::Train::Run.find(params[:id])

    if @release.finished_steps?
      @release.start_post_release_phase!
      redirect_back fallback_location: root_path, notice: "Performing post-release steps."
    else
      redirect_back fallback_location: root_path, notice: "Train is still running."
    end
  end

  private

  def set_release
    @release = Releases::Train::Run.joins(train: :app).where(apps: {organization: current_organization}).find(params[:id])
  end

  def live_release_path
    live_release_app_train_releases_path(@app, @train)
  end
end

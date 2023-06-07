class ReleasesController < SignedInApplicationController
  using RefinedString
  around_action :set_time_zone
  before_action :require_write_access!, only: %i[create destroy post_release]
  before_action :set_release, only: [:show, :timeline, :destroy]

  def show
    @train = @release.train
    @steps = @train.steps.order(:step_number).includes(:runs, :train, deployments: [:integration])
    @app = @train.app
    set_pull_requests
    set_demo_mode_things

    if demo_train?
      render :show_demo
    else
      render :show
    end
  end

  def create
    @app = current_organization.apps.friendly.find(params[:app_id])
    @train = @app.trains.friendly.find(params[:train_id])
    @has_major_bump = params[:has_major_bump]&.to_boolean

    response = Triggers::Release.call(@train, has_major_bump: @has_major_bump)

    if response.success?
      redirect_to live_release_path, notice: "A new release has started successfully."
    else
      redirect_back fallback_location: root_path, flash: {error: response.body}
    end
  end

  def timeline
    @train = @release.train
    @app = @train.app
    @events = @release.events
  end

  def live_release
    @app = current_organization.apps.friendly.find(params[:app_id])
    @train = @app.trains.friendly.find(params[:train_id])
    @steps = @train.steps.order(:step_number).includes(:runs, :train, deployments: [:integration])
    @release = @train.active_run
    redirect_to train_path, notice: "No release in progress." and return unless @release
    set_pull_requests
    set_demo_mode_things

    if demo_train?
      render :show_demo
    else
      render :show
    end
  end

  def destroy
    @release.stop!
    redirect_to app_train_path(@release.train.app, @release.train), notice: "The release was stopped."
  end

  # TODO: This action can be deprecated once there are no more releases with pending manual finalize
  # Since finalize as of https://github.com/tramlinehq/tramline/pull/440 is automatic
  def post_release
    @release = Releases::Train::Run.find(params[:id])

    if @release.finalizable?
      @release.start_post_release_phase!
      redirect_back fallback_location: root_path, notice: "Performing post-release steps."
    else
      redirect_back fallback_location: root_path, notice: "Train is still running."
    end
  end

  private

  def set_release
    @release =
      Releases::Train::Run
        .joins(train: :app)
        .where(apps: {organization: current_organization})
        .find(params[:id])
  end

  def set_pull_requests
    @pre_release_prs = @release.pull_requests.pre_release
    @post_release_prs = @release.pull_requests.post_release
  end

  def live_release_path
    live_release_app_train_releases_path(@app, @train)
  end

  def set_demo_mode_things
    @events = @release.events(10)
  end

  def train_path
    app_train_path(@app, @train)
  end
end

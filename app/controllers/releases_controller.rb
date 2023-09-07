class ReleasesController < SignedInApplicationController
  using RefinedString
  around_action :set_time_zone
  before_action :require_write_access!, only: %i[create destroy post_release]
  before_action :set_release, only: [:show, :timeline, :destroy]

  def show
    @train = @release.train
    @app = @train.app
    set_commits
    set_pull_requests

    render :show
  end

  def create
    @app = current_organization.apps.friendly.find(params[:app_id])
    @train = @app.trains.friendly.find(params[:train_id])
    @has_major_bump = params[:has_major_bump]&.to_boolean

    response = Triggers::Release.call(@train, has_major_bump: @has_major_bump)

    if response.success?
      redirect_to current_release_path(response.body), notice: "A new release has started successfully."
    else
      redirect_back fallback_location: root_path, flash: {error: response.body}
    end
  end

  def live_release
    @app = current_organization.apps.friendly.find(params[:app_id])
    @train = @app.trains.friendly.find(params[:train_id])
    @release = @train.ongoing_release

    show_current_release
  end

  alias_method :ongoing_release, :live_release

  def upcoming_release
    @app = current_organization.apps.friendly.find(params[:app_id])
    @train = @app.trains.friendly.find(params[:train_id])
    @release = @train.upcoming_release

    show_current_release
  end

  def show_current_release
    redirect_to train_path, notice: "No release in progress." and return unless @release

    set_commits
    set_pull_requests

    render :show
  end

  def destroy
    @release.stop!
    redirect_to app_train_path(@release.train.app, @release.train), notice: "The release was stopped."
  end

  # TODO: This action can be deprecated once there are no more releases with pending manual finalize
  # Since finalize as of https://github.com/tramlinehq/tramline/pull/440 is automatic
  def post_release
    @release = Release.find(params[:id])

    if @release.ready_to_be_finalized?
      @release.force_finalize = post_release_params[:force_finalize]
      @release.start_post_release_phase!
      redirect_back fallback_location: root_path, notice: "Performing post-release steps."
    else
      redirect_back fallback_location: root_path, notice: "Train is still running."
    end
  end

  def timeline
    @train = @release.train
    @app = @train.app
    @events = @release.events
  end

  private

  def post_release_params
    params.require(:release).permit(:force)
  end

  def set_release
    @release =
      Release
        .joins(train: :app)
        .where(apps: {organization: current_organization})
        .find(params[:id])
  end

  def set_pull_requests
    @pre_release_prs = @release.pull_requests.pre_release
    @post_release_prs = @release.pull_requests.post_release
    @ongoing_open_release_prs = @release.pull_requests.ongoing.open
  end

  def set_commits
    @commits = @release.applied_commits.sequential.includes(step_runs: :step)
  end

  def current_release_path(current_release)
    release_path(current_release)
  end

  def train_path
    app_train_path(@app, @train)
  end
end

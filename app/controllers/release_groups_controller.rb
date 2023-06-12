class ReleaseGroupsController < SignedInApplicationController
  using RefinedString
  around_action :set_time_zone
  before_action :require_write_access!, only: %i[create destroy post_release]
  before_action :set_release, only: [:show, :timeline, :destroy]

  def show
    @train_group = @release.train_group
    @app = @train_group.app
    set_train_stuff
    set_pull_requests

    render :show
  end

  def create
    @app = current_organization.apps.friendly.find(params[:app_id])
    @train_group = @app.train_groups.friendly.find(params[:train_group_id])
    @has_major_bump = params[:has_major_bump]&.to_boolean

    response = Triggers::ReleaseGroup.call(@train_group, has_major_bump: @has_major_bump)

    if response.success?
      redirect_to live_release_path, notice: "A new release has started successfully."
    else
      redirect_back fallback_location: root_path, flash: {error: response.body}
    end
  end

  def live_release
    @app = current_organization.apps.friendly.find(params[:app_id])
    @train_group = @app.train_groups.friendly.find(params[:train_group_id])
    @release = @train_group.active_run
    redirect_to train_group_path, notice: "No release in progress." and return unless @release

    set_train_stuff
    set_pull_requests

    render :show
  end

  def destroy
    @release.stop!
    redirect_to app_train_group_path(@release.train_group.app, @release.train_group), notice: "The release was stopped."
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

  def timeline
    @train = @release.train
    @app = @train.app
    @events = @release.events
  end

  private

  def set_train_stuff
    @ios_train = @train_group.ios_train
    @android_train = @train_group.android_train
    @ios_steps = @ios_train.steps.order(:step_number).includes(:runs, :train, deployments: [:integration]) if @ios_train
    @android_steps = @android_train.steps.order(:step_number).includes(:runs, :train, deployments: [:integration]) if @android_train
    @android_events = @release.android_run.events(10) if @android_train
    @ios_events = @release.ios_run.events(10) if @ios_train
  end

  def set_release
    @release =
      Releases::TrainGroup::Run
        .joins(train_group: :app)
        .where(apps: {organization: current_organization})
        .find(params[:id])
  end

  def set_pull_requests
    @pre_release_prs = @release.pull_requests.pre_release
    @post_release_prs = @release.pull_requests.post_release
  end

  def live_release_path
    live_release_app_train_group_release_groups_path(@app, @train_group)
  end

  def train_group_path
    app_train_group_path(@app, @train_group)
  end
end

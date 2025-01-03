class ReleasesController < SignedInApplicationController
  using RefinedString
  include Filterable
  include Tabbable
  around_action :set_time_zone
  before_action :require_write_access!, only: %i[create destroy update override_approvals copy_approvals post_release finish_release]
  before_action :set_release, only: %i[show destroy update timeline override_approvals copy_approvals post_release finish_release]
  before_action :set_train_and_app, only: %i[destroy timeline]
  before_action :ensure_approval_items_exist, only: %i[copy_approvals]
  before_action :ensure_approval_items_copyable, only: %i[copy_approvals]

  def index
    @train = @app.trains.friendly.find(params[:train_id])
  end

  def show
    redirect_to live_release_active_tab
  end

  def create
    @train = @app.trains.friendly.find(params[:train_id])

    has_major_bump = parsed_release_params[:has_major_bump]&.to_boolean
    release_type = parsed_release_params[:release_type] || Release.release_types[:release]
    new_hotfix_branch = parsed_release_params[:new_hotfix_branch]&.to_boolean
    hotfix_platform = parsed_release_params[:hotfix_platform]
    custom_version = parsed_release_params[:custom_release_version]

    if release_type == Release.release_types[:hotfix] && !@train.hotfixable?
      redirect_back fallback_location: root_path, flash: {error: "Cannot start hotfix for this train!"} and return
    end

    result = Action.start_release!(@train, has_major_bump:, release_type:, new_hotfix_branch:, hotfix_platform:, custom_version:)

    if result.ok?
      redirect_to current_release_path(result.value!), notice: "A new release has started successfully."
    else
      redirect_back fallback_location: root_path, flash: {error: result.error.message}
    end
  end

  def update
    if @release.update(update_release_params)
      redirect_to overview_release_path(@release), notice: "Captain's log was updated!"
    else
      redirect_back fallback_location: root_path, flash: {error: "Captain's log could not be updated."}
    end
  end

  def override_approvals
    if @release.override_approvals(current_user)
      redirect_to release_approval_items_path(@release), notice: "Approvals have been overridden. The release can move ahead."
    else
      redirect_back fallback_location: root_path, flash: {error: "Approvals could not be overridden."}
    end
  end

  def copy_approvals
    if @release.copy_previous_approvals
      redirect_to release_approval_items_path(@release), notice: "Approvals have been successfully copied."
    else
      redirect_back fallback_location: root_path, flash: {error: "Unable to copy approvals from previous release."}
    end
  end

  def overview
    live_release!
    set_train_and_app
    set_pull_requests
  end

  def changeset_tracking
    live_release!
    set_train_and_app
    set_pull_requests
  end

  def regression_testing
    live_release!
    set_train_and_app
  end

  def soak
    live_release!
    set_train_and_app
  end

  def wrap_up_automations
    live_release!
    set_train_and_app
  end

  def live_release
    @train = @app.trains.friendly.find(params[:train_id])
    @release = @train.ongoing_release

    show_current_release
  end

  alias_method :ongoing_release, :live_release

  def upcoming_release
    @train = @app.trains.friendly.find(params[:train_id])
    @release = @train.upcoming_release

    show_current_release
  end

  def hotfix_release
    @app = current_organization.apps.friendly.find(params[:app_id])
    @train = @app.trains.friendly.find(params[:train_id])
    @release = @train.hotfix_release

    show_current_release
  end

  def show_current_release
    redirect_to train_path, notice: "No release in progress." and return unless @release
    redirect_to release_path(@release)
  end

  def destroy
    if (res = Action.stop_release!(@release)).ok?
      redirect_to train_path, notice: "The release was stopped."
    else
      redirect_to train_path, flash: {error: res.error.message}
    end
  end

  # TODO: This action can be deprecated once there are no more releases with pending manual finalize
  # Since finalize as of https://github.com/tramlinehq/tramline/pull/440 is automatic
  def post_release
    if Action.complete_release!(@release).ok?
      redirect_back fallback_location: root_path, notice: "Performing post-release steps."
    else
      redirect_back fallback_location: root_path, notice: "Train could not be finalized."
    end
  end

  def finish_release
    if Action.mark_release_as_finished!(@release).ok?
      redirect_back fallback_location: root_path, notice: "Performing post-release steps."
    else
      redirect_back fallback_location: root_path, notice: "Release is not partially finished. You cannot mark it as finished yet."
    end
  end

  def timeline
    @events_params = filterable_params.except(:id)
    gen_query_filters(:android_platform, "android")
    gen_query_filters(:ios_platform, "ios")
    set_query_helpers
    @events = Queries::Events.all(release: @release, params: @query_params)
  end

  private

  def set_train_and_app
    @train = @release.train
    @app = @train.app
  end

  def set_release
    @release =
      Release
        .joins(train: :app)
        .where(apps: {organization: current_organization})
        .friendly.find(params[:id])
  end

  def set_pull_requests
    @pre_release_prs = @release.pre_release_prs
    @post_release_prs = @release.post_release_prs
    @ongoing_open_release_prs = @release.backmerge_prs.open
    @mid_release_prs = @release.mid_release_prs
  end

  def current_release_path(current_release)
    release_path(current_release)
  end

  def train_path
    app_train_releases_path(@app, @train)
  end

  def release_params
    params.permit(release: [
      :new_hotfix_branch,
      :release_type,
      :has_major_bump,
      :hotfix_platform,
      :platform_specific_hotfix,
      :custom_release_version,
      :internal_notes
    ])[:release] || {}
  end

  def parsed_release_params
    release_params
      .merge(hotfix_config(release_params.slice(:hotfix_platform, :platform_specific_hotfix)))
      .except(:platform_specific_hotfix)
  end

  def update_release_params
    release_params.slice(:internal_notes)
  end

  def hotfix_config(config_params)
    if config_params[:platform_specific_hotfix].blank? || config_params[:platform_specific_hotfix] == "false"
      {hotfix_platform: nil}
    elsif config_params[:platform_specific_hotfix] == "true"
      {hotfix_platform: config_params[:hotfix_platform]}
    end
  end

  def ensure_approval_items_exist
    if @release.approval_items.exists?
      redirect_back fallback_location: root_path, flash: {error: "Cannot copy approvals: approval items already exist."}
    end
  end

  def ensure_approval_items_copyable
    unless @release.copy_approvals_allowed?
      redirect_back fallback_location: root_path, flash: {error: "Cannot copy over approvals."}
    end
  end
end

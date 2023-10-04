class TrainsController < SignedInApplicationController
  using RefinedString
  using RefinedInteger

  before_action :require_write_access!, only: %i[new create edit update destroy activate deactivate]
  before_action :set_app, only: %i[new create show edit update destroy activate deactivate]
  around_action :set_time_zone
  before_action :set_train, only: %i[show edit update destroy activate deactivate]
  before_action :validate_integration_status, only: %i[new create]
  before_action :set_notification_channels, only: %i[new create edit update]

  def show
  end

  def new
    @train = @app.trains.new
  end

  def edit
  end

  def create
    @train = @app.trains.new(parsed_train_params)

    if @train.save
      new_train_redirect
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @train.update(parsed_train_update_params)
      redirect_to train_path, notice: "Train was updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @train.destroy
      redirect_to app_path(@app), status: :see_other, notice: "Train was deleted!"
    else
      render :show, status: :unprocessable_entity
    end
  end

  def activate
    if @train.activate!
      redirect_to train_path, notice: "Train was activated!"
    else
      render :show, status: :unprocessable_entity
    end
  end

  def deactivate
    redirect_to train_path, notice: "Can not deactivate with an ongoing release" and return if @train.active_runs.exists?

    if @train.deactivate!
      redirect_to train_path, notice: "Train was deactivated!"
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def new_train_redirect
    if @train.in_creation? && @app.trains.size == 1
      redirect_to app_path(@app), notice: "Train was successfully created."
    else
      redirect_to train_path, notice: "Train was successfully created."
    end
  end

  def set_train
    @train = @app.trains.friendly.find(params[:id])
  end

  def set_app
    @app = current_organization.apps.friendly.find(params[:app_id])
  end

  def train_params
    params.require(:train).permit(
      :name,
      :description,
      :working_branch,
      :working_repo,
      :version_seeded_with,
      :major_version_seed,
      :minor_version_seed,
      :patch_version_seed,
      :branching_strategy,
      :release_backmerge_branch,
      :release_branch,
      :kickoff_at,
      :repeat_duration_value,
      :repeat_duration_unit,
      :notification_channel,
      :build_queue_enabled,
      :build_queue_size,
      :build_queue_wait_time_unit,
      :build_queue_wait_time_value,
      :release_schedule_enabled,
      :continuous_backmerge_enabled,
      :manual_release,
      :compact_build_notes,
      :tag_all_store_releases,
      :tag_platform_releases,
      :notifications_enabled
    )
  end

  def parsed_train_params
    release_schedule_params = release_schedule_config(train_params.slice(*release_schedule_config_params))
    create_params = train_params
      .merge(build_queue_config(train_params.slice(*build_queue_config_params)))
      .merge(backmerge_config(train_params[:continuous_backmerge_enabled]))
      .merge(notifications_config(train_params[:notifications_enabled]))
      .except(:build_queue_wait_time_value, :build_queue_wait_time_unit, :continuous_backmerge_enabled, :notifications_enabled)
      .except(*release_schedule_config_params)
    create_params.merge!(release_schedule_params) if release_schedule_params
    create_params
  end

  def train_update_params
    params.require(:train).permit(
      :name,
      :description,
      :notification_channel,
      :build_queue_enabled,
      :build_queue_size,
      :build_queue_wait_time_unit,
      :build_queue_wait_time_value,
      :kickoff_at,
      :repeat_duration_value,
      :repeat_duration_unit,
      :release_schedule_enabled,
      :continuous_backmerge_enabled,
      :manual_release,
      :compact_build_notes,
      :tag_all_store_releases,
      :tag_platform_releases,
      :notifications_enabled
    )
  end

  def parsed_train_update_params
    release_schedule_params = release_schedule_config(train_update_params.slice(*release_schedule_config_params))
    update_params = train_update_params
      .merge(build_queue_config(train_update_params.slice(*build_queue_config_params)))
      .merge(backmerge_config(train_update_params[:continuous_backmerge_enabled]))
      .merge(notifications_config(train_update_params[:notifications_enabled]))
      .except(:build_queue_wait_time_value, :build_queue_wait_time_unit, :continuous_backmerge_enabled)
      .except(*release_schedule_config_params)
    update_params.merge!(release_schedule_params) if release_schedule_params
    update_params
  end

  def validate_integration_status
    redirect_to app_path, alert: "Cannot create trains before notifiers are complete." unless @app.ready?
  end

  def train_path
    app_train_path(@app, @train)
  end

  def set_notification_channels
    @notification_channels = @app.notification_provider.channels if @app.notifications_set_up?
    @current_notification_channel = @train&.notification_channel || @app.config.notification_channel
  end

  def build_queue_config_params
    [:build_queue_size, :build_queue_enabled, :build_queue_wait_time_value, :build_queue_wait_time_unit]
  end

  def build_queue_config(config_params)
    unless config_params[:build_queue_enabled] == "true"
      return {
        build_queue_size: nil,
        build_queue_wait_time: nil
      }
    end

    return if config_params[:build_queue_wait_time_unit].blank?
    return if config_params[:build_queue_wait_time_value].blank?
    return if config_params[:build_queue_size].blank?

    {
      build_queue_wait_time: parsed_duration(config_params[:build_queue_wait_time_value], config_params[:build_queue_wait_time_unit]),
      build_queue_size: config_params[:build_queue_size]
    }
  end

  def release_schedule_config_params
    [:release_schedule_enabled, :kickoff_at, :repeat_duration_value, :repeat_duration_unit]
  end

  def release_schedule_config(config_params)
    return if config_params[:release_schedule_enabled].blank?

    {
      repeat_duration: parsed_duration(config_params[:repeat_duration_value], config_params[:repeat_duration_unit]),
      kickoff_at: config_params[:kickoff_at]&.time_in_utc
    }
  end

  def parsed_duration(value, unit)
    return if unit.blank? || value.blank?
    value.to_i.as_duration_with(unit: unit)
  end

  def backmerge_config(continuous_backmerge_enabled)
    if continuous_backmerge_enabled.blank? || continuous_backmerge_enabled == "false"
      {backmerge_strategy: Train.backmerge_strategies[:on_finalize]}
    elsif continuous_backmerge_enabled == "true"
      {backmerge_strategy: Train.backmerge_strategies[:continuous]}
    end
  end

  def notifications_config(notifications_enabled)
    if notifications_enabled.blank? || notifications_enabled == "false"
      {notification_channel: nil}
    elsif notifications_enabled == "true"
      {notification_channel: train_params[:notification_channel]&.safe_json_parse}
    end
  end
end

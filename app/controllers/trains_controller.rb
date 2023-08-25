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
    if @train.build_queue_wait_time.present?
      parts = @train.build_queue_wait_time.parts
      @train.build_queue_wait_time_unit = parts.keys.first.to_s
      @train.build_queue_wait_time_value = parts.values.first
    end

    if @train.repeat_duration.present?
      parts = @train.repeat_duration.parts
      @train.repeat_duration_unit = parts.keys.first.to_s
      @train.repeat_duration_value = parts.values.first
    end
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
    redirect_to train_path, notice: "Can not deactivate with an ongoing release" and return if @train.active_run.present?

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
      :build_queue_wait_time_value
    )
  end

  def parsed_train_params
    train_params
      .merge(release_schedule_config(train_params.slice(*release_schedule_config_params)))
      .merge(build_queue_config(train_params.slice(*build_queue_config_params)))
      .except(:repeat_duration_value, :repeat_duration_unit, :build_queue_wait_time_value, :build_queue_wait_time_unit)
      .merge(notification_channel: train_params[:notification_channel]&.safe_json_parse)
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
      :repeat_duration_unit
    )
  end

  def parsed_train_update_params
    train_update_params
      .merge(release_schedule_config(train_update_params.slice(*release_schedule_config_params)))
      .merge(build_queue_config(train_update_params.slice(*build_queue_config_params)))
      .except(:repeat_duration_value, :repeat_duration_unit, :build_queue_wait_time_value, :build_queue_wait_time_unit)
      .merge(notification_channel: train_update_params[:notification_channel]&.safe_json_parse)
  end

  def validate_integration_status
    redirect_to app_path, alert: "Cannot create trains before notifiers are complete." unless @app.ready?
  end

  def train_path
    app_train_path(@app, @train)
  end

  def set_notification_channels
    @notification_channels = @app.notification_provider.channels if @app.notifications_set_up?
    @current_notification_channel = @train.present? ? @train.notification_channel : @app.config.notification_channel
  end

  def build_queue_config_params
    [:build_queue_size, :build_queue_enabled, :build_queue_wait_time_value, :build_queue_wait_time_unit]
  end

  def build_queue_config(build_queue_params)
    return {build_queue_size: nil, build_queue_wait_time: nil} unless build_queue_params[:build_queue_enabled] == "true"

    return if build_queue_params[:build_queue_wait_time_unit].blank?
    return if build_queue_params[:build_queue_wait_time_value].blank?
    return if build_queue_params[:build_queue_size].blank?

    {build_queue_wait_time: build_queue_params[:build_queue_wait_time_value]
      .to_i
      .as_duration_with(unit: build_queue_params[:build_queue_wait_time_unit]),
     build_queue_size: build_queue_params[:build_queue_size]}
  end

  def release_schedule_config_params
    [:kickoff_at, :repeat_duration_value, :repeat_duration_unit]
  end

  def release_schedule_config(schedule_params)
    {repeat_duration: parsed_duration(schedule_params[:repeat_duration_value], schedule_params[:repeat_duration_unit]),
     kickoff_at: time_in_utc(schedule_params[:kickoff_at])}
  end

  def time_in_utc(time)
    return if time.blank?
    Time.zone.parse(time).utc
  end

  def parsed_duration(value, unit)
    return if unit.blank? || value.blank?
    value.to_i.as_duration_with(unit: unit)
  end
end

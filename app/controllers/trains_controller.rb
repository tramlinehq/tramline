class TrainsController < SignedInApplicationController
  using RefinedString
  using RefinedInteger

  before_action :require_write_access!, only: %i[new create edit update destroy activate deactivate]
  before_action :set_app, only: %i[new create show edit update destroy activate deactivate]
  around_action :set_time_zone
  before_action :set_train, only: %i[show edit update destroy activate deactivate]
  before_action :validate_integration_status, only: %i[new create]

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
    if @train.update(train_update_params)
      redirect_to train_path, notice: "Train was updated"
    else
      render :show, status: :unprocessable_entity
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
      :repeat_duration_unit
    )
  end

  def parsed_train_params
    train_params
      .merge(repeat_duration: repeat_duration)
      .merge(kickoff_at: kickoff_at_in_utc)
      .except(:repeat_duration_value, :repeat_duration_unit)
  end

  def repeat_duration
    return if train_params[:repeat_duration_unit].blank?
    return if train_params[:repeat_duration_value].blank?

    train_params[:repeat_duration_value]
      .to_i
      .as_duration_with(unit: train_params[:repeat_duration_unit])
  end

  def kickoff_at_in_utc
    return if train_params[:kickoff_at].blank?
    Time.parse(train_params[:kickoff_at]).in_time_zone.utc
  end

  def train_update_params
    params.require(:train).permit(
      :name,
      :description
    )
  end

  def validate_integration_status
    redirect_to app_path, alert: "Cannot create trains before notifiers are complete." unless @app.ready?
  end

  def train_path
    app_train_path(@app, @train)
  end
end

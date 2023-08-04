class TrainsController < SignedInApplicationController
  using RefinedString
  using RefinedInteger

  before_action :require_write_access!, only: %i[new create edit update destroy activate]
  before_action :set_app, only: %i[new create show edit update destroy activate]
  around_action :set_time_zone
  before_action :set_train, only: %i[show edit update destroy activate]
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

    respond_to do |format|
      if @train.save
        format.html { new_train_redirect }
        format.json { render :show, status: :created, location: @train }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @train.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @train.update(train_update_params)
        format.html { redirect_to train_path, notice: "Train was updated" }
        format.json { render :show, status: :ok, location: @train }
      else
        format.html { render :show, status: :unprocessable_entity }
        format.json { render json: @train.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    respond_to do |format|
      if @train.destroy
        format.html { redirect_to app_path(@app), status: :see_other, notice: "Train was deleted!" }
      else
        format.html { render :show, status: :unprocessable_entity }
      end
    end
  end

  def activate
    respond_to do |format|
      if @train.activate!
        format.html { redirect_to train_path, notice: "Train was activated!" }
        format.json { render :show, status: :ok, location: @train }
      else
        format.html { render :show, status: :unprocessable_entity }
        format.json { render json: @train.errors, status: :unprocessable_entity }
      end
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
      .merge(repeat_duration: repeat_duration_in_iso8601(train_params))
      .except(:repeat_duration_value, :repeat_duration_unit)
  end

  def repeat_duration_in_iso8601(train_params)
    return if train_params[:repeat_duration_value].blank?
    Duration.new(train_params[:repeat_duration_unit] => train_params[:repeat_duration_value]).iso8601
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

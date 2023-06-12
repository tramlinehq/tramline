class TrainGroupsController < SignedInApplicationController
  using RefinedString
  using RefinedInteger

  before_action :require_write_access!, only: %i[new create edit update destroy]
  before_action :set_app, only: %i[new create show edit update destroy]
  around_action :set_time_zone
  before_action :set_train_group, only: %i[show edit update destroy]
  before_action :validate_integration_status, only: %i[new create]

  def show
  end

  def new
    @train_group = @app.train_groups.new
    @ios_train = @train_group.trains.new(app: @app)
    @android_train = @train_group.trains.new(app: @app)
  end

  def edit
  end

  def create
    @train_group = @app.train_groups.new(train_group_params)

    respond_to do |format|
      if @train_group.save
        format.html { new_train_group_redirect }
        format.json { render :show, status: :created, location: @train_group }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @train_group.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @train_group.update(train_group_update_params)
        format.html { redirect_to train_group_path, notice: "Train was updated" }
        format.json { render :show, status: :ok, location: @train_group }
      else
        format.html { render :show, status: :unprocessable_entity }
        format.json { render json: @train_group.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    respond_to do |format|
      if @train_group.destroy
        format.html { redirect_to app_path(@app), status: :see_other, notice: "Train was deleted!" }
      else
        format.html { render :show, status: :unprocessable_entity }
      end
    end
  end

  private

  def new_train_group_redirect
    if @train_group.in_creation?
      redirect_to app_path(@app), notice: "Train was successfully created."
    else
      redirect_to train_group_path, notice: "Train was successfully created."
    end
  end

  def set_train_group
    @train_group = @app.train_groups.friendly.find(params[:id])
  end

  def set_app
    @app = current_organization.apps.friendly.find(params[:app_id])
  end

  def train_group_params
    params.require(:releases_train_group).permit(
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
      :release_branch
    )
  end

  def train_group_update_params
    params.require(:train_group).permit(
      :name,
      :description
    )
  end

  def validate_integration_status
    redirect_to app_path, alert: "Cannot create trains before notifiers are complete." unless @app.ready?
  end

  def train_group_path
    app_train_group_path(@app, @train)
  end
end

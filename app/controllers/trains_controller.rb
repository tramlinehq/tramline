class TrainsController < SignedInApplicationController
  using RefinedString
  using RefinedInteger

  before_action :set_app, only: %i[new create show index edit update destroy deactivate start]
  around_action :set_time_zone
  before_action :set_train, only: %i[show edit update destroy deactivate start]
  before_action :validate_integration_status, only: %i[new create]

  def new
    @train = @app.trains.new
  end

  def create
    @train = @app.trains.new(train_params)

    respond_to do |format|
      if @train.save
        format.html { redirect_to train_path, notice: "Train was successfully created." }
        format.json { render :show, status: :created, location: @train }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @train.errors, status: :unprocessable_entity }
      end
    end
  end

  def deactivate
    params = {
      status: Releases::Train.statuses[:inactive]
    }

    respond_to do |format|
      if @train.update(params)
        format.html { redirect_to train_path, notice: "Train was successfully deactivated!" }
        format.json { render :show, status: :created, location: @train }
      else
        format.html { render :show, status: :unprocessable_entity }
        format.json { render json: @train.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @train.update(train_update_params)
        format.html { redirect_to train_path, notice: "Train was updated" }
        format.json { render :show, status: :created, location: @train }
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

  def show
  end

  def index
  end

  def edit
  end

  private

  def set_train
    @train = @app.trains.friendly.find(params[:id])
  end

  def set_app
    @app = current_organization.apps.friendly.find(params[:app_id])
  end

  def train_params
    params.require(:releases_train).permit(
      :name,
      :description,
      :working_branch,
      :working_repo,
      :version_seeded_with,
      :branching_strategy,
      :release_backmerge_branch,
      :release_branch,
      sign_off_group_ids: []
    )
  end

  def train_update_params
    params.require(:releases_train).permit(
      :name,
      :description,
      sign_off_group_ids: []
    )
  end

  def validate_integration_status
    redirect_to app_path, alert: "Cannot create trains before notifiers are complete." unless @app.ready?
  end

  def train_path
    app_train_path(@app, @train)
  end
end

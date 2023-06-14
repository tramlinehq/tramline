class TrainsController < SignedInApplicationController
  using RefinedString
  using RefinedInteger

  before_action :require_write_access!, only: %i[edit update]
  before_action :set_app, only: %i[show edit update]
  around_action :set_time_zone
  before_action :set_train, only: %i[show edit update]

  def show
  end

  def edit
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

  private

  def set_train
    @train = @app.trains.friendly.find(params[:id])
  end

  def set_app
    @app = current_organization.apps.friendly.find(params[:app_id])
  end

  def train_update_params
    params.require(:releases_train).permit(
      :name,
      :description
    )
  end

  def train_path
    app_train_path(@app, @train)
  end
end

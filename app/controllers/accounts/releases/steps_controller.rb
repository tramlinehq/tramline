class Accounts::Releases::StepsController < ApplicationController
  before_action :set_app, only: %i[new create show edit update]
  before_action :set_train, only: %i[new create show edit update]
  before_action :set_step, only: %i[show edit update]

  def new
    @step = @train.steps.new
  end

  def create
    @step = @train.steps.new(step_params)
    @step.status = "inactive"

    respond_to do |format|
      if @step.save!
        format.html {
          redirect_to accounts_organization_app_releases_train_step_path(current_organization, @app, @train, @step),
            notice: "Step was successfully created."
        }
        format.json { render :show, status: :created, location: @step }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @step.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    return if @step.status.running?

    respond_to do |format|
      if @step.update(train_params)
        format.html {
          redirect_to accounts_organization_app_path(current_organization, @step),
            notice: "Step was successfully updated."
        }
        format.json { render :show, status: :ok, location: @step }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @step.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def show
  end

  def index
  end

  private

  def set_step
    @step = @train.steps.find(params[:id])
  end

  def set_train
    @train = @app.trains.find(params[:train_id])
  end

  def set_app
    @app = current_organization.apps.friendly.find(params[:app_id])
  end

  def step_params
    params.require(:releases_step).permit(
      :name,
      :description,
      :build_artifact_channel,
      :ci_cd_channel
    )
  end
end

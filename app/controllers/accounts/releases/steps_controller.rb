class Accounts::Releases::StepsController < ApplicationController
  before_action :set_app, only: %i[new create show edit update]
  before_action :set_train, only: %i[new create show edit update]
  before_action :set_step, only: %i[show edit update]
  before_action :set_first_step, only: %i[new create]

  def new
    @step = @train.steps.new

    unless @train.integrations_are_ready?
      redirect_to accounts_organization_app_releases_train_url(current_organization, @app, @train),
                  alert: "You haven't yet completed your integrations!"
    end

    @ci_actions = @train.integrations.ci_cd.first.channels
    @build_channels = @train.integrations.notification.first.channels
  end

  def create
    @step = @train.steps.new(parsed_step_params)

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
    @step = @train.steps.friendly.find(params[:id])
  end

  def set_train
    @train = @app.trains.friendly.find(params[:train_id])
  end

  def set_app
    @app = current_organization.apps.friendly.find(params[:app_id])
  end

  def set_first_step
    @first_step = true if @train.steps.count < 1
  end

  def step_params
    params.require(:releases_step).permit(
      :name,
      :description,
      :build_artifact_channel,
      :ci_cd_channel,
      :run_after_duration_unit,
      :run_after_duration_value
    )
  end

  def parsed_step_params
    step_params
      .merge(status: "inactive")
      .merge(run_after_duration:)
      .except(:run_after_duration_unit, :run_after_duration_value)
  end

  def run_after_duration
    return 0.seconds if @first_step

    ActiveSupport::Duration.parse(
      Duration.new(step_params[:run_after_duration_unit].to_sym =>
                     step_params[:run_after_duration_value].to_i).iso8601
    )
  end
end

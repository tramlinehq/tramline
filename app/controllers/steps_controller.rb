class StepsController < SignedInApplicationController
  using RefinedString
  using RefinedInteger

  before_action :require_write_access!, only: %i[new create edit update]
  before_action :set_app, only: %i[new create]
  before_action :set_train, only: %i[new create]
  before_action :set_ci_actions, only: %i[new create]
  before_action :set_build_channels, only: %i[new create]
  before_action :integrations_are_ready?, only: %i[new create]
  around_action :set_time_zone

  def new
    head 403 and return if @train.active_run
    @step = @train.steps.new
  end

  def create
    head 403 and return if @train.active_run
    @step = @train.steps.new(parsed_step_params)

    respond_to do |format|
      if @step.save
        format.html { redirect_to app_train_path(@app, @train), notice: "Step was successfully created." }
        format.json { render :show, status: :created, location: @step }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @step.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
    @step =
      Releases::Step
        .joins(train: :app)
        .where(trains: {apps: {organization: current_organization}})
        .friendly
        .find(params[:id])
    @train = @step.train
    head 403 and return if @train.active_run
    @ci_actions = @train.ci_cd_provider.workflows
  end

  def update
    @step =
      Releases::Step
        .joins(train: :app)
        .where(trains: {apps: {organization: current_organization}})
        .friendly
        .find(params[:id])
    @train = @step.train
    head 403 and return if @train.active_run

    @app = @train.app

    if @step.update(parsed_step_params)
      redirect_to edit_app_train_path(@app, @train), notice: "Step was successfully updated."
    else
      @ci_actions = @train.ci_cd_provider.workflows
      render :edit, status: :unprocessable_entity
    end
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

  def step_params
    params.require(:releases_step).permit(
      :name,
      :description,
      :build_artifact_channel,
      :ci_cd_channel,
      :build_artifact_integration,
      :release_suffix
    )
  end

  def parsed_step_params
    step_params
      .merge(parsed_deployments_params)
      .merge(ci_cd_channel: step_params[:ci_cd_channel]&.safe_json_parse)
  end

  def integrations_are_ready?
    unless @train.ready?
      redirect_to app_train_path(@app, @train), alert: "Cannot create steps before notifiers are complete."
    end
  end

  def set_ci_actions
    @ci_actions = @train.ci_cd_provider.workflows
  end

  def set_build_channels
    @build_channel_integrations = @train.build_channel_integrations
    @selected_integration = @build_channel_integrations.first
    @selected_build_channels = Integration.find_by(id: @selected_integration).providable.channels
  end

  def deployments_params
    params
      .require(:releases_step)
      .permit(deployments_attributes: [:integration_id, :build_artifact_channel, :deployment_number])
  end

  def parsed_deployments_params
    deployments_params.merge(deployments_attributes: parsed_deployments_attributes)
  end

  def parsed_deployments_attributes
    deployments_params[:deployments_attributes].to_h.to_h do |number, attributes|
      [number, attributes.merge(build_artifact_channel: attributes[:build_artifact_channel]&.safe_json_parse)]
    end
  end
end

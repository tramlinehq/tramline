class StepsController < SignedInApplicationController
  using RefinedString
  using RefinedInteger

  before_action :set_app, only: %i[new create show]
  before_action :set_train, only: %i[new create show]
  before_action :set_ci_actions, only: %i[new create]
  before_action :set_build_channels, only: %i[new create]
  before_action :set_step, only: %i[show]
  before_action :set_first_step, only: %i[new create]
  before_action :integrations_are_ready?, only: %i[new create]
  around_action :set_time_zone

  def new
    @step = @train.steps.new
  end

  def create
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
    @step = Releases::Step.joins(train: :app).where(trains: {apps: {organization: current_organization}}).friendly.find(params[:id])
    @train = @step.train
    @build_channels = @train.notification_provider.channels
    @ci_actions = @train.ci_cd_provider.workflows
  end

  def update
    @step = Releases::Step.joins(train: :app).where(trains: {apps: {organization: current_organization}}).friendly.find(params[:id])
    @train = @step.train
    @app = @train.app
    if @step.update(parsed_step_params)
      redirect_to edit_app_train_path(@app, @train), notice: "Step was successfully updated."
    else
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

  def set_first_step
    @first_step = true if @train.steps.count < 1
  end

  def step_params
    params.require(:releases_step).permit(
      :name,
      :description,
      :build_artifact_channel,
      :ci_cd_channel
    )
  end

  def parsed_step_params
    step_params
      .merge(build_artifact_channel: step_params[:build_artifact_channel]&.safe_json_parse)
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
    @build_channels = @train.notification_provider.channels
  end
end

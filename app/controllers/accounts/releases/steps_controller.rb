class Accounts::Releases::StepsController < SignedInApplicationController
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
        format.html { redirect_to step_path, notice: "Step was successfully created." }
        format.json { render :show, status: :created, location: @step }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @step.errors, status: :unprocessable_entity }
      end
    end
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
      .merge(run_after_duration: run_after_duration)
      .merge(build_artifact_channel: step_params[:build_artifact_channel].safe_json_parse)
      .merge(ci_cd_channel: step_params[:ci_cd_channel].safe_json_parse)
      .except(:run_after_duration_unit, :run_after_duration_value)
  end

  def run_after_duration
    return 0.seconds if @first_step

    step_params[:run_after_duration_value]
      .to_i
      .as_duration_with(unit: step_params[:run_after_duration_unit])
  end

  def integrations_are_ready?
    unless @train.integrations_are_ready?
      redirect_to train_path, alert: "Cannot create steps before notifiers are complete."
    end
  end

  def train_path
    accounts_organization_app_releases_train_path(current_organization, @app, @train)
  end

  def step_path
    accounts_organization_app_releases_train_step_path(current_organization, @app, @train, @step)
  end

  def set_ci_actions
    @ci_actions = @train.integrations.ci_cd.first.workflows
  end

  def set_build_channels
    @build_channels = @train.integrations.notification.first.channels
  end
end

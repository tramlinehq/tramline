class Accounts::Releases::TrainsController < SignedInApplicationController
  using RefinedString
  using RefinedInteger

  before_action :set_app, only: %i[new create show index edit update activate]
  around_action :set_time_zone
  before_action :set_train, only: %i[show edit update activate]
  before_action :validate_integration_status, only: %i[new create]

  def new
    @train = @app.trains.new
  end

  def create
    @train = @app.trains.new(parsed_train_params)

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

  def show
  end

  def index
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
      :version_suffix,
      :kickoff_at,
      :repeat_duration_value,
      :repeat_duration_unit
    )
  end

  def parsed_train_params
    train_params
      .merge(repeat_duration: repeat_duration)
      .merge(kickoff_at: train_params[:kickoff_at].in_tz(@app.timezone))
      .except(:repeat_duration_value, :repeat_duration_unit)
  end

  def repeat_duration
    train_params[:repeat_duration_value]
      .to_i
      .as_duration_with(unit: train_params[:repeat_duration_unit])
  end

  def validate_integration_status
    unless @app.integrations_are_ready?
      redirect_to app_path, alert: "Cannot create trains before notifiers are complete."
    end
  end

  def app_path
    accounts_organization_app_path(current_organization, @app)
  end

  def train_path
    accounts_organization_app_releases_train_path(current_organization, @app, @train)
  end
end

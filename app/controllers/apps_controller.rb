class AppsController < SignedInApplicationController
  before_action :set_app, only: %i[show edit update]
  before_action :set_integrations, only: %i[show]
  around_action :set_time_zone

  def new
    @timezones = default_timezones
    @app = current_organization.apps.new
  end

  def create
    @app = current_organization.apps.new(app_params)

    respond_to do |format|
      if @app.save
        format.html { redirect_to app_path(@app), notice: "App was successfully created." }
        format.json { render :show, status: :created, location: @app }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @app.errors, status: :unprocessable_entity }
      end
    end
  end

  def show
  end

  def index
    @apps = current_organization.apps
  end

  private

  def set_integrations
    @integrations = @app.integrations
  end

  def set_app
    @app = current_organization.apps.friendly.includes(:trains).find(params[:id])
  end

  def app_params
    params.require(:app).permit(
      :name,
      :description,
      :bundle_identifier,
      :build_number,
      :timezone
    )
  end

  DEFAULT_TIMEZONE_LIST_REGEX = /Asia\/Kolkata/

  def default_timezones
    ActiveSupport::TimeZone.all.select { |tz| tz.match?(DEFAULT_TIMEZONE_LIST_REGEX) }
  end
end

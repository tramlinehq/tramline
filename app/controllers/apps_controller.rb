class AppsController < SignedInApplicationController
  include Pagy::Backend

  before_action :require_write_access!, only: %i[new create edit update destroy]
  before_action :set_app, only: %i[show edit update destroy all_builds]
  before_action :set_integrations, only: %i[show destroy]
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
    @setup_instructions = @app.setup_instructions
  end

  def edit
  end

  def update
    respond_to do |format|
      if @app.update(app_update_params)
        format.html { redirect_to app_path(@app), notice: "App was updated." }
        format.json { render :show, status: :updated, location: @app }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @app.errors, status: :unprocessable_entity }
      end
    end
  end

  def index
    @apps = current_organization.apps
  end

  def destroy
    respond_to do |format|
      if @app.destroy
        format.html { redirect_to apps_path, status: :see_other, notice: "App was deleted!" }
      else
        format.html { render :show, status: :unprocessable_entity }
      end
    end
  end

  def all_builds
    @sort_column = params[:sort_column]
    @sort_direction = params[:sort_direction]
    @path = nil
    @pagy, @builds = pagy(@app.all_builds(column: @sort_column, direction: @sort_direction))
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
      :platform,
      :build_number,
      :timezone
    )
  end

  def app_update_params
    app_params.except(:timezone)
  end

  DEFAULT_TIMEZONE_LIST_REGEX = /Asia\/Kolkata/

  def default_timezones
    ActiveSupport::TimeZone.all.select { |tz| tz.match?(DEFAULT_TIMEZONE_LIST_REGEX) }
  end
end

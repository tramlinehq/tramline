class AppsController < SignedInApplicationController
  include Pagy::Backend
  include Filterable
  include Tabbable

  before_action :require_write_access!, only: %i[create edit update destroy]
  before_action :set_integrations, only: %i[show destroy]
  before_action :set_app_config_tabs, only: %i[edit update]
  around_action :set_time_zone

  def index
    @apps = current_organization.apps
    if @apps.exists?
      redirect_to app_path(@apps.first)
    end
  end

  def show
    @app = default_app

    if @app.trains.exists?
      selected_train = @app.trains.find(&:has_production_deployment?) || @app.trains.first
      redirect_to app_train_releases_path(@app, selected_train)
    end

    @train_in_creation = @app.train_in_creation
    @app_setup_instructions = @app.app_setup_instructions
  end

  def edit
  end

  def create
    @app = current_organization.apps.new(app_params)

    if @app.save
      redirect_to app_path(@app), notice: "App was successfully created."
    else
      @apps = current_organization.apps
      redirect_back fallback_location: apps_path, flash: {error: "#{@app.errors.full_messages.to_sentence}."}
    end
  end

  def update
    if @app.update(app_update_params)
      redirect_to app_path(@app), notice: "App was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @app.destroy
      redirect_to apps_path, status: :see_other, notice: "App was deleted!"
    else
      redirect_back fallback_location: apps_path, flash: {error: "Could not remove the app. #{@app.errors.full_messages.to_sentence}."}
    end
  end

  def all_builds
    @all_builds_params = filterable_params.except(:id)
    gen_query_filters(:release_status, ReleasePlatformRun.statuses[:finished])
    set_query_helpers
    set_query_pagination(Queries::Builds.count(app: @app, params: @query_params))
    @builds = Queries::Builds.all(app: @app, params: @query_params)
  end

  def search
    Rails.logger.debug("@@@PARAMS: #{params}")
    all_releases

    respond_to do |format|
      format.html {}
      format.turbo_stream do
        render turbo_stream: turbo_stream.update("all_releases",
          partial: "apps/all_releases_search_results",
          locals: { releases: @releases, pagy: @pagy, all_releases_params: @all_releases_params, app: @app, filters: @filters })
      end
    end
  end

  def all_releases
    @all_releases_params = filterable_params.except(:id)
    gen_query_filters(:release_status, Release.statuses[:finished])
    set_query_helpers
    @query_params.add_search_query(params[:search_pattern]) if params[:search_pattern].present?
    set_query_pagination(Queries::Releases.count(app: @app, params: @query_params))
    @releases = Queries::Releases.all(app: @app, params: @query_params)
  end

  def refresh_external
    @app.create_external!
    redirect_to app_path(@app), notice: "Store status was successfully refreshed."
  end

  private

  def set_integrations
    @integrations = @app.integrations
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

  def app_id_key
    :id
  end
end

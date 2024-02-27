class AppsController < SignedInApplicationController
  include Pagy::Backend
  include Filterable

  before_action :require_write_access!, only: %i[create edit update destroy]
  before_action :set_integrations, only: %i[show destroy]
  before_action :set_tab_config, only: %i[edit update]
  around_action :set_time_zone

  def index
    @apps = current_organization.apps
    if @apps.exists?
      redirect_to app_path(@apps.first)
    end
  end

  def show
    @app = default_app

    if @app.trains.size > 1 || (@app.trains.size == 1 && !@app.trains.first.in_creation?)
      selected_train = @app.trains.find(&:has_production_deployment?) || @app.trains.first
      redirect_to app_train_releases_path(@app, selected_train)
    end

    @train_in_creation = @app.train_in_creation
    @app_setup_instructions = @app.app_setup_instructions
    @train_setup_instructions = @app.train_setup_instructions
  end

  def edit
  end

  def create
    @app = current_organization.apps.new(app_params)

    respond_to do |format|
      if @app.save
        format.html { redirect_to app_path(@app), notice: "App was successfully created." }
        format.json { render :show, status: :created, location: @app }
      else
        format.html { render :index, status: :unprocessable_entity }
        format.json { render json: @app.errors, status: :unprocessable_entity }
      end
    end
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
    @all_builds_params = filterable_params.except(:id)
    gen_query_filters(:release_status, ReleasePlatformRun.statuses[:finished])
    set_query_helpers
    set_query_pagination(Queries::Builds.count(app: @app, params: @query_params))
    @builds = Queries::Builds.all(app: @app, params: @query_params)
  end

  def refresh_external
    @app.create_external!

    redirect_to app_path(@app), notice: "Store status was successfully refreshed."
  end

  private

  def set_tab_config
    @tab_configuration = [
      [1, "General", edit_app_path(@app), "v2/cog.svg"],
      [2, "Integrations", app_integrations_path(@app), "v2/blocks.svg"],
      [3, "App Variants", app_app_config_app_variants_path(@app), "dna.svg"]
    ]
  end

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

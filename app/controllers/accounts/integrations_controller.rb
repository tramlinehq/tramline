class Accounts::IntegrationsController < ApplicationController
  before_action :set_app, only: %i[new create show edit update index]
  before_action :set_integration, only: %i[edit show update]

  def new
    @integration = @app.integrations.new
  end

  def create
    @integration = @app.integrations.new(integration_params)
    @integration.decide

    redirect_to(@integration.install_path, allow_other_host: true)
  end

  def update
    respond_to do |format|
      if @integration.update(integration_params)
        format.html { redirect_to accounts_organization_app_integration_path(current_organization, @app, @integration), notice: "Integration was successfully updated." }
        format.json { render :show, status: :ok, location: @integration }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @integration.errors, status: :unprocessable_entity }
      end
    end
  end

  def show
  end

  def edit
    @active_repository_names =
      Integrations::Github::Api.new(@integration.installation_id).repos[:repositories].map(&:full_name)
  end

  def index
  end

  private

  def set_integration
    @integration = @app.integrations.find(params[:id])
  end

  def set_app
    @app = current_organization.apps.friendly.find(params[:app_id])
  end

  def integration_params
    params.require(:integration)
          .permit(:category, :provider, :active_code_repo, :working_branch)
          .merge(current_user: current_user)
  end
end

class Accounts::IntegrationsController < ApplicationController
  require "string_utils"
  using StringUtils

  before_action :set_app, only: %i[new create show edit update index]
  before_action :set_integration, only: %i[edit show update]

  def new
    @integration = @app.integrations.new
  end

  def create
    @integration = @app.integrations.new(integration_params)
    redirect_to("https://github.com/apps/#{ENV["GITHUB_APP_NAME"]}/installations/new?state=#{state}", allow_other_host: true)
  end

  def update
    respond_to do |format|
      if @integration.update(integration_params)
        format.html { redirect_to accounts_organization_app_integration_path(current_organization, @app, @integration), notice: "Deck was successfully updated." }
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
      Integrations::Github::Api.new(ENV["GITHUB_APP_ID"], @integration.installation_id).repos[:repositories].map(&:full_name)
  end

  def index
  end

  private

  def state
    {
      organization_id: current_organization.id,
      app_id: @app.id,
      integration_category: Integration.categories[:version_control],
      integration_provider: Integration.providers[:github],
      user_id: current_user.id
    }.to_json.encrypt
  end

  def set_integration
    @integration = @app.integrations.find(params[:id])
  end

  def set_app
    @app = current_organization.apps.friendly.find(params[:app_id])
  end

  def integration_params
    params.require(:integration).permit(:category, :provider, :active_repo)
  end
end

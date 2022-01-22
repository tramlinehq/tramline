class Accounts::IntegrationsController < ApplicationController
  before_action :set_app, only: %i[new create show index github_auth_code_callback]

  GITHUB_CLIENT_ID = "173f1b65d5e09eb15c70"
  GITHUB_CLIENT_SECRET = "82c3d644efa7a2462bbfd9a83389f59f08e116aa"

  def new
    @integration = @app.integrations.new
  end

  def create
    @integration = @app.integrations.new(integration_params)
    redirect_to(github_authorize_url, allow_other_host: true, protocol: "https://")
  end

  def show
  end

  def index
  end

  def github_auth_code_callback
    @code = params[:code]
    puts "Got code: #{@code}"
    head :ok

    # respond_to do |format|
    #   if @integration.save
    #     format.html { redirect_to @integration, notice: "Integration was successfully created." }
    #     format.json { render :show, status: :created, location: @integration }
    #   else
    #     format.html { render :new, status: :unprocessable_entity }
    #     format.json { render json: @integration.errors, status: :unprocessable_entity }
    #   end
    # end
  end

  private

  def github_authorize_url
    Github.new(client_id: GITHUB_CLIENT_ID, client_secret: GITHUB_CLIENT_SECRET)
      .authorize_url(scope: "repo:status")
  end

  def set_app
    @app = current_organization.apps.friendly.find(params[:app_id])
  end

  def integration_params
    params.require(:integration).permit(:name, :kind)
  end
end

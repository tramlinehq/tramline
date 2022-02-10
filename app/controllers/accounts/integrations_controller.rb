class Accounts::IntegrationsController < SignedInApplicationController
  using RefinedString

  before_action :set_app, only: %i[new connect show edit update index]
  before_action :set_integration, only: %i[edit show update]

  def new
    @integrations_by_categories =
      Integration::LIST.each_with_object({}) do |(category, providers), combination|
        # don't allow re-creating an integration that already exists
        next if @app.integrations.where(category: category).exists?

        combination[category] ||= []

        providers.each do |provider|
          integration =
            @app
              .integrations
              .new(category: Integration.categories[category], provider: Integration.providers[provider])

          combination[category] << integration
        end

        combination
      end
  end

  def connect
    @integration = @app.integrations.new(integration_params)
    @integration.decide

    redirect_to(@integration.install_path, allow_other_host: true)
  end

  def update
    respond_to do |format|
      if @integration.update(parsed_integration_params)
        format.html {
          redirect_to accounts_organization_app_integration_path(current_organization, @app, @integration),
                      notice: "Integration was successfully updated."
        }
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
    @channels = @integration.channels
  end

  def index
    @integrations = @app.integrations
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
          .permit(
            :category,
            :provider,
            :active_code_repo,
            :working_branch,
            :notification_channel
          ).merge(current_user:)
  end

  def parsed_integration_params
    integration_params
      .merge(active_code_repo: integration_params[:active_code_repo]&.safe_json_parse)
      .merge(notification_channel: integration_params[:notification_channel]&.safe_json_parse)
      .merge(status: Integration.statuses[:fully_connected])
  end
end

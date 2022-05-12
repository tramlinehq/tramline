class Accounts::IntegrationsController < SignedInApplicationController
  using RefinedString

  before_action :set_app, only: %i[connect index create]
  before_action :set_integration, only: %i[connect create]
  before_action :set_providable, only: %i[connect create]

  def connect
    redirect_to(@integration.install_path, allow_other_host: true)
  end

  def create
    if @integration.save!
      redirect_to index_path, notice: "Integration was successfully created."
    else
      redirect_to index_path, notice: "Integration failed!"
    end
  end

  def index
    @integrations_by_categories =
      Integration::LIST.each_with_object({}) do |(category, providers), combination|
        existing_integration = @app.integrations.where(category: category)
        combination[category] ||= []

        if existing_integration.exists?
          combination[category] << existing_integration.first
          next
        end

        providers.each do |provider|
          integration =
            @app
              .integrations
              .new(category: Integration.categories[category], providable: provider.constantize.new)

          combination[category] << integration
        end

        combination
      end
  end

  private

  def set_app
    @app = current_organization.apps.friendly.find(params[:app_id])
  end

  def set_integration
    @integration = @app.integrations.new(integrations_only_params)
  end

  def set_providable
    @integration.providable = providable_type.constantize.new(integration: @integration)
    @integration.providable.assign_attributes(additional_providable_params)
  end

  def integration_params
    params.require(:integration)
          .permit(
            :category,
            providable: [:json_key, :type]
          ).merge(current_user:)
  end

  def integrations_only_params
    integration_params.except(:providable)
  end

  def providable_params
    integration_params[:providable]
  end

  def additional_providable_params
    params = {}
    params = params.merge(json_key: attachment) if providable_type.eql?("GooglePlayStoreIntegration")
    params
  end

  def providable_type
    providable_params[:type]
  end

  def attachment
    Services::Attachment.for_json(integration_params[:providable][:json_key])
  end

  def index_path
    accounts_organization_app_integrations_path(@current_organization, @app)
  end
end

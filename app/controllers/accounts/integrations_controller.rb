class Accounts::IntegrationsController < SignedInApplicationController
  using RefinedString

  before_action :set_app, only: %i[connect index]


  def connect
    @integration = @app.integrations.new(connect_params)
    @integration.providable = build_providable

    redirect_to(@integration.install_path, allow_other_host: true)
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

  def build_providable
    providable_params[:providable].constantize.new(integration: @integration)
  end

  def integration_params
    params.require(:integration)
          .permit(
            :category,
            :providable
          ).merge(current_user:)
  end

  def connect_params
    integration_params.except(:providable)
  end

  def providable_params
    integration_params.except(:category)
  end
end

class IntegrationsController < SignedInApplicationController
  using RefinedString

  before_action :set_app, only: %i[connect index create]
  before_action :set_integration, only: %i[connect create]
  before_action :set_providable, only: %i[connect create]

  def connect
    redirect_to(@integration.install_path, allow_other_host: true)
  end

  def create
    if @integration.save
      redirect_to index_path, notice: "Integration was successfully created."
    else
      set_integrations_by_categories
      render :index, status: :unprocessable_entity
    end
  end

  def index
    set_integrations_by_categories
  end

  def build_artifact_channels
    id = params[:id]

    @target = params[:target]
    @build_channels =
      if id.blank?
        [["External", {"external" => "external"}.to_json]] # TODO: Have a better abstraction instead of if conditions
      else
        Integration.find_by(id: id).providable.channels
      end

    respond_to(&:turbo_stream)
  end

  private

  def set_integrations_by_categories
    @integrations_by_categories =
      Integration::LIST.each_with_object({}) do |(category, providers), combination|
        existing_integration = @app.integrations.where(category: category)
        combination[category] ||= []

        if existing_integration.exists?
          existing_integration.each do |integration|
            combination[category] << integration
          end

          next if Integration::MULTI_INTEGRATION_CATEGORIES.exclude?(category)
        end

        (providers - existing_integration.pluck(:providable_type)).each do |provider|
          next if provider.eql?("GitlabIntegration") && !Flipper.enabled?(:gitlab_integration)

          integration =
            @app
              .integrations
              .new(category: Integration.categories[category],
                providable: provider.constantize.new,
                status: Integration::DEFAULT_INITIAL_STATUS)

          combination[category] << integration
        end

        combination
      end
  end

  def set_app
    @app = current_organization.apps.friendly.find(params[:app_id])
  end

  def set_integration
    @integration = @app.integrations.new(integrations_only_params)
  end

  def set_providable
    @integration.providable = providable_type.constantize.new(integration: @integration)
    @integration.providable.assign_attributes(providable_params)
  end

  def integration_params
    params.require(:integration)
      .permit(
        :category,
        providable: [:type]
      ).merge(current_user:)
  end

  def integrations_only_params
    integration_params.except(:providable)
  end

  def providable_params
    {}
  end

  def providable_type
    integration_params[:providable][:type]
  end

  def index_path
    app_integrations_path(@app)
  end
end

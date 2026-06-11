class IntegrationsController < SignedInApplicationController
  using RefinedString
  include Tabbable

  before_action :require_write_access!, only: %i[connect create build_artifact_channels destroy reauth rotate]
  before_action :set_app_config_tabs, only: %i[index]
  before_action :set_integration, only: %i[connect create reuse]
  before_action :set_existing_integration, only: %i[reuse]
  before_action :set_providable, only: %i[connect create]
  before_action :set_reauth_integration, only: %i[reauth]
  before_action :set_rotate_integration, only: %i[rotate]

  def connect
    redirect_to(@integration.install_path, allow_other_host: true)
  end

  def index
    @pre_open_category = Integration.categories[params[:integration_category]]
    set_integrations_by_categories
  end

  def reuse
    return redirect_to app_integrations_path(@app), alert: "Integration not found or not connected." unless @existing_integration&.connected?

    update_new_integration!

    if @integration.save
      redirect_to app_integrations_path(@app), notice: "#{@existing_integration.providable_type} integration reused successfully."
    else
      redirect_to app_integrations_path(@app), flash: {error: @integration.errors.full_messages.to_sentence}
    end
  end

  def reauth
    redirect_to(@reauth_integration.install_path, allow_other_host: true)
  end

  def rotate
    rotate_params = build_rotate_params
    return redirect_to app_integrations_path(@app), flash: {error: @rotate_error} if @rotate_error

    if @rotate_integration.providable.rotate(**rotate_params)
      redirect_to app_integrations_path(@app), notice: "Credentials were successfully rotated."
    else
      redirect_to app_integrations_path(@app), flash: {error: @rotate_integration.providable.errors.full_messages.to_sentence}
    end
  end

  def create
    if @integration.save
      redirect_to app_path(@app), notice: "Integration was successfully created."
    else
      redirect_to app_integrations_path(@app), flash: {error: @integration.errors.full_messages.to_sentence}
    end
  end

  def build_artifact_channels
    @target = params[:target]
    with_production = params[:with_production]&.to_boolean
    @build_channels = Integration.find_build_channels(params[:integration_id], with_production:)

    respond_to(&:turbo_stream)
  end

  def destroy
    @integration = @app.integrations.find(params[:id])

    unless @integration.disconnectable?
      redirect_back fallback_location: root_path,
        flash: {error: "Cannot disconnect since the integration is currently being used by a release or in a step."}
      return
    end

    if @integration.disconnect
      redirect_to app_integrations_path(@app), notice: "Integration was successfully disconnected."
    else
      redirect_to app_integrations_path(@app), flash: {error: @integration.errors.full_messages.to_sentence}
    end
  end

  private

  def update_new_integration!
    @integration.status = Integration.statuses[:connected]
    @integration.metadata = @existing_integration.metadata
    new_providable = @existing_integration.providable.dup
    new_providable.integration = @integration
    @integration.providable = new_providable
  end

  def set_integrations_by_categories
    @integrations_by_categories = Integration.by_categories_for(@app)
  end

  def set_integration
    @integration = @app.integrations.new(integrations_only_params)
  end

  def set_existing_integration
    @existing_integration = Integration.find_by(id: params[:integration][:existing_integration_id])
  end

  def set_reauth_integration
    @reauth_integration = @app.integrations.needs_reauth.find(params[:id])
    @reauth_integration.current_user = current_user
    # the current_user should be reflected correctly in the associated providable
    @reauth_integration.providable.integration = @reauth_integration
  end

  def set_rotate_integration
    @rotate_integration = @app.integrations.linked.find(params[:id])
    raise ActiveRecord::RecordNotFound unless @rotate_integration.providable.rotatable?
  end

  def build_rotate_params
    case @rotate_integration.providable_type
    when "AppStoreIntegration" then app_store_rotate_params
    else raise ActiveRecord::RecordNotFound
    end
  end

  def app_store_rotate_params
    permitted = params.require(:integration).require(:providable).permit(:key_id, :issuer_id, :p8_key_file)
    p8_key_file = permitted[:p8_key_file]

    file_errors = Validators::KeyFileValidator.validate(p8_key_file).errors
    if file_errors.present?
      @rotate_error = file_errors.first
      return {}
    end

    {
      key_id: permitted[:key_id],
      issuer_id: permitted[:issuer_id],
      p8_key: p8_key_file.read
    }
  end

  def set_providable
    @integration.providable = providable_type.constantize.new(integration: @integration)
    set_providable_params
  end

  def set_providable_params
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

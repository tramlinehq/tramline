class AppVariantIntegrationsController < SignedInApplicationController
  using RefinedString

  before_action :require_write_access!, only: %i[create destroy]
  before_action :set_app_variant
  before_action :set_integration, only: %i[create]
  before_action :set_providable, only: %i[create]

  def create
    if @integration.save
      redirect_to app_app_variants_path(@app), notice: t("integrations.app_variant.integration_created")
    else
      redirect_to app_app_variants_path(@app), flash: {error: @integration.errors.full_messages.to_sentence}
    end
  end

  def destroy
    @integration = @app_variant.integrations.find(params[:id])

    if @integration.disconnect
      redirect_to app_app_variants_path(@app), notice: t("integrations.app_variant.integration_disconnected")
    else
      redirect_to app_app_variants_path(@app), flash: {error: @integration.errors.full_messages.to_sentence}
    end
  end

  private

  def set_app_variant
    @app_variant = @app.variants.friendly.find(params[:app_variant_id])
  end

  def set_integration
    @integration = @app_variant.integrations.new(integrations_only_params)
  end

  def set_providable
    unless Integration::APP_VARIANT_PROVIDABLE_TYPES.include?(providable_type)
      redirect_to app_app_variants_path(@app), flash: {error: t("integrations.app_variant.invalid_provider")}
      return
    end

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
end

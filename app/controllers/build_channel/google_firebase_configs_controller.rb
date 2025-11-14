class BuildChannel::GoogleFirebaseConfigsController < SignedInApplicationController
  using RefinedString

  before_action :require_write_access!
  before_action :set_integrable
  before_action :set_google_firebase_integration
  around_action :set_time_zone

  def edit
    set_firebase_apps

    respond_to do |format|
      format.html do |variant|
        variant.turbo_frame { render :edit }
      end
    end
  end

  def update
    if @google_firebase_integration.update(parsed_google_firebase_config_params)
      redirect_to app_path(@app), notice: t(".success")
    else
      redirect_back fallback_location: app_integrations_path(@integrable),
                    flash: { error: @google_firebase_integration.errors.full_messages.to_sentence }
    end
  end

  private

  def set_integrable
    # current_organization.apps.friendly.find(params[:app_id])
    @integrable = Integrable.find(params[:integrable_id])
  end

  def set_google_firebase_integration
    @google_firebase_integration = @integrable&.integrations&.firebase_build_channel_provider
    unless @google_firebase_integration.is_a?(GoogleFirebaseIntegration)
      redirect_to app_integrations_path(@app), flash: { error: "Firebase build channel integration not found." }
    end
  end

  def set_firebase_apps
    config = @google_firebase_integration.setup
    @firebase_android_apps, @firebase_ios_apps = config[:android], config[:ios]
  end

  def parsed_google_firebase_config_params
    google_firebase_config_params =
      params
        .require(:google_firebase_integration)
        .permit(:android_config, :ios_config)

    google_firebase_config_params
      .merge(
        ios_config: google_firebase_config_params[:ios_config]&.safe_json_parse,
        android_config: google_firebase_config_params[:android_config]&.safe_json_parse
      )
  end
end

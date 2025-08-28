class Firebase::ConfigsController < SignedInApplicationController
  using RefinedString

  before_action :require_write_access!, only: %i[update]
  before_action :set_firebase_integration, only: %i[edit update]
  around_action :set_time_zone

  def edit
    respond_to do |format|
      format.html do |variant|
        variant.turbo_frame do
          set_firebase_apps if @integration.further_setup?
          render "firebase/configs/edit"
        end
      end

      format.turbo_stream do
        set_firebase_apps if @integration.further_setup?
        render "firebase/configs/edit"
      end
    end
  end

  def update
    if @integration.update(firebase_config_params)
      redirect_to app_path(@app), notice: "Firebase configuration was successfully updated."
    else
      redirect_back fallback_location: edit_app_path(@app), flash: {error: @integration.errors.full_messages.to_sentence}
    end
  end

  private

  def set_firebase_integration
    @integration = @app.integrations.firebase_build_channel_provider
    unless @integration&.providable
      redirect_to app_path(@app), flash: {error: "Firebase integration not found."}
    end
  end

  def firebase_config_params
    params
      .require(:google_firebase_integration)
      .permit(
        :android_config,
        :ios_config
      )
      .merge(
        android_config: params[:google_firebase_integration][:android_config]&.safe_json_parse,
        ios_config: params[:google_firebase_integration][:ios_config]&.safe_json_parse
      )
      .compact
  end

  def set_firebase_apps
    config = @integration.providable.setup
    @firebase_android_apps, @firebase_ios_apps = config[:android], config[:ios]
  end
end
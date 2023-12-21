class AppVariantsController < SignedInApplicationController
  using RefinedString
  before_action :require_write_access!, only: %i[create update]
  around_action :set_time_zone

  def create
    @config = @app.config
    @app_variant = @config.variants.new(parsed_app_variant_params)

    if @app_variant.save
      redirect_to edit_app_app_config_path, notice: "App Variant was successfully created."
    else
      redirect_back fallback_location: edit_app_app_config_path, flash: {error: @app_variant.errors.full_messages.to_sentence}
    end
  end

  def update
  end

  private

  def app_variant_params
    params.require(:app_variant)
      .permit(:name, :bundle_identifier, :firebase_android_config, :firebase_ios_config)
  end

  def parsed_app_variant_params
    app_variant_params
      .merge(firebase_ios_config: app_variant_params[:firebase_ios_config]&.safe_json_parse)
      .merge(firebase_android_config: app_variant_params[:firebase_android_config]&.safe_json_parse)
      .compact
  end
end

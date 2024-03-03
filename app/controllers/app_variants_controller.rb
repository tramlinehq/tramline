class AppVariantsController < SignedInApplicationController
  using RefinedString
  before_action :require_write_access!, only: %i[create update]
  around_action :set_time_zone

  def index
    @tab_configuration = [
      [1, "General", edit_app_path(@app), "v2/cog.svg"],
      [2, "Integrations", app_integrations_path(@app), "v2/blocks.svg"],
      [3, "App Variants", app_app_config_app_variants_path(@app), "dna.svg"]
    ]
    @config = @app.config
    @app_variants = @config.variants.to_a
    @new_app_variant = @config.variants.build
    setup_config = @app.integrations.firebase_build_channel_provider&.setup

    if setup_config
      @firebase_android_apps, @firebase_ios_apps = setup_config[:android], setup_config[:ios]
    else
      @unconfigured = true
    end
  end

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

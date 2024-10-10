class AppVariantsController < SignedInApplicationController
  using RefinedString
  include Tabbable

  before_action :require_write_access!, only: %i[create update index]
  before_action :set_app_config_tabs, only: %i[index]
  before_action :set_app_variant, only: %i[edit update destroy]
  before_action :ensure_valid_providable_params, only: %i[create]
  around_action :set_time_zone

  def index
    @config = @app.config
    @app_variants = @config.variants.to_a
    @new_app_variant = @config.variants.build
    @none = @app_variants.empty?
  end

  def edit
    @app_config = @app_variant.app_config
    @app = @app_config.app
    set_firebase_app_configs
  end

  def create
    @app_variant = @app.config.variants.new(create_params)
    set_firebase_integration

    if @app_variant.save
      redirect_to default_path, notice: "App Variant was successfully created."
    else
      @app_variant.errors.merge!(@integration)
      redirect_back fallback_location: default_path, flash: {error: @app_variant.errors.full_messages.to_sentence}
    end
  end

  def update
    if @app_variant.update(update_params)
      redirect_to default_path, notice: "App Variant was successfully updated."
    else
      redirect_back fallback_location: default_path, flash: {error: @app_variant.errors.full_messages.to_sentence}
    end
  end

  def destroy
    if @app_variant.destroy
      redirect_to default_path, notice: "App Variant was deleted."
    else
      redirect_to default_path, flash: {error: "There was an error: #{@app_variant.errors.full_messages.to_sentence}"}
    end
  end

  private

  def set_app_variant
    @app_variant = AppVariant.find(params[:id])
    @app_config = @app_variant.app_config
    @app = @app_config.app
  end

  def app_variant_params
    @app_variant_params ||=
      params
        .require(:app_variant)
        .permit(:name,
          :bundle_identifier,
          :firebase_android_config,
          :firebase_ios_config,
          integrations: [:category, providable: [:json_key_file, :type, :project_number]])
  end

  def create_params
    app_variant_params.except(:integrations)
  end

  def update_params
    create_params
      .merge(firebase_ios_config: create_params[:firebase_ios_config]&.safe_json_parse)
      .merge(firebase_android_config: create_params[:firebase_android_config]&.safe_json_parse)
      .compact
  end

  def json_key_file
    @json_key_file ||= integration_providable_params[:json_key_file]
  end

  def providable_params_errors
    @providable_params_errors ||= Validators::KeyFileValidator.validate(json_key_file).errors
  end

  def set_firebase_integration
    integration_params = app_variant_params[:integrations].except(:providable)
    providable = integration_providable_params[:type].constantize.new(integration: @integration)
    providable_params = {json_key: json_key_file.read, project_number: integration_providable_params[:project_number]}
    @integration = @app_variant.integrations.new(integration_params.merge(providable:))
    @integration.providable.assign_attributes(providable_params)
  end

  def integration_providable_params
    app_variant_params[:integrations][:providable]
  end

  def ensure_valid_providable_params
    if providable_params_errors.present?
      redirect_back fallback_location: default_path, flash: {error: providable_params_errors.first}
    end
  end

  def set_firebase_app_configs
    config = @app_variant.integrations.firebase_build_channel_provider.setup
    @firebase_android_apps, @firebase_ios_apps = config[:android], config[:ios]
  end

  def default_path
    app_app_config_app_variants_path(@app)
  end
end

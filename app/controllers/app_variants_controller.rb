class AppVariantsController < SignedInApplicationController
  include Tabbable

  before_action :require_write_access!, only: %i[create update]
  before_action :set_app_config_tabs, only: %i[index]
  before_action :set_app_variant, only: %i[edit update destroy]
  around_action :set_time_zone

  def index
    @app_variants = @app.variants.to_a
    @new_app_variant = @app.variants.build
    @none = @app_variants.empty?
  end

  def edit
  end

  def create
    @app_variant = @app.variants.new(app_variant_params)

    if @app_variant.save
      redirect_to default_path, notice: "App Variant was successfully created. Configure integrations below."
    else
      redirect_back fallback_location: default_path, flash: {error: @app_variant.errors.full_messages.to_sentence}
    end
  end

  def update
    if @app_variant.update(app_variant_params)
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
    @app_variant = AppVariant.friendly.find(params[:id])
    @app = @app_variant.app
  end

  def app_variant_params
    params.require(:app_variant).permit(:name, :bundle_identifier)
  end

  def default_path
    app_app_variants_path(@app)
  end
end

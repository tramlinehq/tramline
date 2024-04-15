class ReleaseHealthRulesController < SignedInApplicationController
  before_action :require_write_access!, only: %i[create destroy]
  before_action :set_train, only: %i[create destroy]
  before_action :set_release_platform, only: %i[create destroy]

  def create
    @rule = @release_platform.release_health_rules.new(rule_params)

    if @rule.save
      redirect_back fallback_location: rules_app_train_path(@app, @train), flash: {notice: t(".success")}
    else
      redirect_back fallback_location: rules_app_train_path(@app, @train), flash: {error: t(".failure", errors: @rule.errors.full_messages.to_sentence)}
    end
  end

  def destroy
    @rule = @release_platform.release_health_rules.find(params[:id])

    if @rule.discard
      redirect_back fallback_location: rules_app_train_path(@app, @train), flash: {notice: t(".success")}
    else
      redirect_back fallback_location: rules_app_train_path(@app, @train), flash: {error: t(".failure", errors: @rule.errors.full_messages.to_sentence)}
    end
  end

  private

  def set_train
    @train = @app.trains.friendly.find(params[:train_id])
  end

  def set_release_platform
    @release_platform = @train.release_platforms.friendly.find(params[:platform_id])
  end

  def rule_params
    params
      .require(:release_health_rule)
      .permit(:name,
        filter_rule_expressions_attributes: [:metric, :comparator, :threshold_value],
        trigger_rule_expressions_attributes: [:metric, :comparator, :threshold_value])
  end
end

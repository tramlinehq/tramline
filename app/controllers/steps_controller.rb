class StepsController < SignedInApplicationController
  using RefinedString
  using RefinedInteger

  before_action :require_write_access!, only: %i[new create update]
  before_action :set_train, only: %i[new create update]
  before_action :set_release_platform, only: %i[new create update]
  before_action :set_ci_actions, only: %i[new create]
  before_action :integrations_are_ready?, only: %i[new create]
  around_action :set_time_zone

  def new
    kind = params.extract!(:kind).require(:kind)

    head :forbidden and return if @train.active_runs.exists?
    head :forbidden and return if kind.blank?

    @step = @release_platform.steps.new(kind:)

    if @step.release? && @release_platform.has_release_step?
      redirect_back fallback_location: app_train_releases_path(@app, @train), flash: {error: "You can only have one release step in a train!"}
    end

    set_build_channels
  end

  def create
    head :forbidden and return if @train.active_runs.exists?
    @step = @release_platform.steps.new(parsed_step_params)

    respond_to do |format|
      if @step.save
        format.html { new_step_redirect }
      else
        set_build_channels
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    @step =
      Step
        .joins(release_platform: :app)
        .where(release_platforms: {apps: {organization: current_organization}})
        .friendly
        .find(params[:id])
    head :forbidden and return if @train.active_runs.exists?

    if @step.update(parsed_step_params)
      redirect_to steps_app_train_path(@app, @train), notice: "Step was successfully updated."
    else
      @ci_actions = @step.ci_cd_provider.workflows
      redirect_to steps_app_train_path(@app, @train), flash: {error: @step.errors.full_messages.to_sentence}
    end
  end

  private

  def new_step_redirect
    if @app.guided_train_setup?
      redirect_to app_path(@app), notice: "Step was successfully created."
    else
      redirect_to app_train_releases_path(@app, @train), notice: "Step was successfully created."
    end
  end

  def set_step
    @step = @train.steps.friendly.find(params[:id])
  end

  def set_train
    @train = @app.trains.friendly.find(params[:train_id])
  end

  def set_release_platform
    @release_platform = @train.release_platforms.friendly.find(params[:platform_id])
  end

  def step_params
    params.require(:step).permit(
      :name,
      :description,
      :ci_cd_channel,
      :release_suffix,
      :kind,
      :auto_deploy,
      :build_artifact_name_pattern,
      :app_variant_id
    )
  end

  def parsed_step_params
    step_params
      .merge(parsed_deployments_params)
      .merge(ci_cd_channel: step_params[:ci_cd_channel]&.safe_json_parse)
  end

  def integrations_are_ready?
    unless @train.ready?
      redirect_to app_train_releases_path(@app, @train), alert: "Cannot create steps before notifiers are complete."
    end
  end

  def set_ci_actions
    @ci_actions = @train.ci_cd_provider.workflows
  end

  def set_build_channels
    @build_channel_integrations = set_build_channel_integrations
    @selected_integration = @build_channel_integrations.first # TODO: what is first even?
    @selected_build_channels =
      Integration.find_build_channels(@selected_integration.last, with_production: @step.release?)
  end

  def deployments_params
    params
      .require(:step)
      .permit(deployments_attributes: [
        :integration_id,
        :build_artifact_channel,
        :deployment_number,
        :is_staged_rollout,
        :notes,
        :staged_rollout_config
      ])
  end

  def parsed_deployments_params
    deployments_params.merge(deployments_attributes: parsed_deployments_attributes)
  end

  def parsed_deployments_attributes
    deployments_params[:deployments_attributes].to_h.to_h do |number, attributes|
      [
        number,
        attributes.merge(
          staged_rollout_config: attributes[:staged_rollout_config]&.safe_csv_parse,
          build_artifact_channel: attributes[:build_artifact_channel]&.safe_json_parse
        )
      ]
    end
  end

  def set_build_channel_integrations
    @release_platform
      .build_channel_integrations
      .map { |bc| [bc.providable.display, bc.id] }
      .push(Integration::EXTERNAL_BUILD_INTEGRATION[:build_integration])
  end
end

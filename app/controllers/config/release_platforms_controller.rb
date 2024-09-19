class Config::ReleasePlatformsController < SignedInApplicationController
  before_action :require_write_access!, only: %i[edit update]
  before_action :set_train, only: %i[edit update]
  before_action :set_app_from_train, only: %i[edit update]
  before_action :set_release_platform, only: %i[edit update]
  before_action :set_config, only: %i[edit update]
  before_action :set_tab_configuration, only: %i[edit update]

  def edit
    @selected_config = @config
    @other_config = @train.release_platforms.where.not(id: @release_platform.id).first&.platform_config
    @ci_actions = @train.ci_cd_provider.workflows
    set_submission_types
  end

  def update
    redirect_to edit_app_train_platform_config_path(@app, @train, @release_platform, @config), notice: I18n.t(".success")
    # if @config.update(platform_params)
    #   redirect_to edit_app_train_platform_path(@app, @train, @selected_platform), notice: "Platform configuration was successfully updated."
    # else
    #   @selected_config = @config
    #   @other_config = @train.release_platforms.where.not(id: @release_platform.id).first&.platform_config
    #   @ci_actions = @train.ci_cd_provider.workflows
    #   render :edit
    # end
  end

  private

  def set_train
    @train = Train.friendly.find(params[:train_id])
  end

  def set_app_from_train
    @app = @train.app
  end

  def set_release_platform
    @release_platform = @train.release_platforms.friendly.find(params[:platform_id])
  end

  def set_config
    @config = @release_platform.platform_config
  end

  def set_tab_configuration
    @tab_configuration = [
      [1, "Release Settings", edit_app_train_path(@app, @train), "v2/cog.svg"],
      [2, "Submissions Settings", edit_app_train_platform_config_path(@app, @train, @release_platform, @config), "v2/route.svg"],
      [3, "Notification Settings", app_train_notification_settings_path(@app, @train), "bell.svg"],
      [4, "Release Health Rules", rules_app_train_path(@app, @train), "v2/heart_pulse.svg"],
      [5, "Reldex Settings", edit_app_train_release_index_path(@app, @train), "v2/ruler.svg"]
    ].compact
  end

  def platform_params
    params.require(:config_release_platform).permit(
      :internal_release_enabled,
      :beta_release_enabled,
      :production_release_enabled,
      internal_release_attributes: [:id, :auto_promote, :number, submissions_attributes: [:id, :submission_type, submission_external_attributes: [:identifier]]],
      beta_release_attributes: [:id, :auto_promote, :number, submissions_attributes: [:id, :submission_type, submission_external_attributes: [:identifier]]],
      production_release_attributes: [:id, submissions_attributes: [:rollout_stages, :rollout_enabled]],
      internal_workflow_attributes: [:id, :identifier, :build_artifact_name_pattern],
      release_candidate_workflow_attributes: [:id, :identifier, :build_artifact_name_pattern]
    )
  end

  def set_submission_types
    @submission_types = []
    if @app.ios_store_provider.present?
      @submission_types << {type: "TestFlightSubmission", channels: @app.ios_store_provider.build_channels(with_production: false)}
    end
    if @app.android_store_provider.present?
      @submission_types << {type: "PlayStoreSubmission", channels: @app.android_store_provider.build_channels(with_production: false)}
    end
    if @app.firebase_build_channel_provider.present?
      @submission_types << {type: "GoogleFirebaseSubmission", channels: @app.firebase_build_channel_provider.build_channels}
    end
  end
end

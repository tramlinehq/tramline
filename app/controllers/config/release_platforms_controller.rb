class Config::ReleasePlatformsController < SignedInApplicationController
  include Tabbable
  using RefinedString

  before_action :require_write_access!, only: %i[edit update]
  before_action :set_train, only: %i[edit update]
  before_action :set_app_from_train, only: %i[edit update]
  before_action :set_release_platform, only: %i[update]
  before_action :set_config, only: %i[update]
  before_action :set_tab_configuration, only: %i[edit update]
  before_action :set_ci_actions, only: %i[edit update]
  before_action :set_submission_types, only: %i[edit update]

  def edit
    @edit_not_allowed = @train.active_runs.exists?
    @selected_config = @train.release_platforms.first&.platform_config
    @selected_platform = @selected_config.release_platform
    @selected_label = @selected_platform.display_attr(:platform)
    @other_config = @train.release_platforms.where.not(id: @selected_platform.id).first&.platform_config
    @other_platform = @other_config&.release_platform
    @other_label = @other_platform&.display_attr(:platform)
  end

  def update
    if @config.update(update_config_params)
      redirect_to submission_config_edit_app_train_path(@app, @train), notice: t(".success")
    else
      @selected_config = @config
      @other_config = @train.release_platforms.where.not(id: @release_platform.id).first&.platform_config
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_train
    @train = Train.friendly.friendly.find(params[:id].presence || params[:train_id])
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

  def set_ci_actions
    @ci_actions = @train.ci_cd_provider.workflows
  end

  def set_submission_types
    @submission_types = []

    if @app.ios_store_provider.present?
      @submission_types << {
        type: TestFlightSubmission, channels: @app.ios_store_provider.build_channels(with_production: false)
      }
    end

    if @app.android_store_provider.present?
      @submission_types << {
        type: PlayStoreSubmission, channels: @app.android_store_provider.build_channels(with_production: false)
      }
    end

    if @app.firebase_build_channel_provider.present?
      @submission_types << {
        type: GoogleFirebaseSubmission, channels: @app.firebase_build_channel_provider.build_channels
      }
    end
  end

  # Parse form params and conditionally include or exclude nested models
  def update_config_params
    permitted_params = config_params

    # Conditionally remove attributes if the relevant _enabled param is false
    if permitted_params[:internal_release_enabled] != "true" && permitted_params[:internal_release_attributes].present?
      permitted_params[:internal_workflow_attributes][:_destroy] = "1"
      permitted_params[:internal_release_attributes][:_destroy] = "1"
    end

    if permitted_params[:beta_release_enabled] != "true" && permitted_params[:beta_release_attributes].present?
      permitted_params[:beta_release_attributes][:_destroy] = "1"
    end

    if permitted_params[:production_release_enabled] != "true" && permitted_params[:production_release_attributes].present?
      permitted_params[:production_release_attributes][:_destroy] = "1"
    end

    parse_config_params(permitted_params)
      .except(:internal_release_enabled, :beta_release_enabled, :production_release_enabled)
  end

  # Permit the params for the release platform and its nested attributes
  def config_params
    params.require(:config_release_platform).permit(
      :internal_release_enabled,
      :beta_release_enabled,
      :production_release_enabled,
      internal_release_attributes: [
        :id, :auto_promote, :number,
        submissions_attributes: [
          :id, :submission_type, :_destroy, submission_external_attributes: [:id, :identifier]
        ]
      ],
      beta_release_attributes: [
        :id, :auto_promote, :number,
        submissions_attributes: [
          :id, :submission_type, :_destroy, submission_external_attributes: [:id, :identifier]
        ]
      ],
      production_release_attributes: [
        :id,
        submissions_attributes: [
          :id, :rollout_stages, :rollout_enabled
        ]
      ],
      internal_workflow_attributes: [
        :id, :identifier, :_destroy, :build_artifact_name_pattern
      ],
      release_candidate_workflow_attributes: [
        :id, :identifier, :build_artifact_name_pattern
      ]
    )
  end

  # Populate the 'name' fields based on a static list corresponding to 'identifier'
  def parse_config_params(permitted_params)
    # For internal workflow
    if permitted_params[:internal_workflow_attributes].present? && permitted_params[:internal_workflow_attributes][:identifier].present?
      identifier = permitted_params[:internal_workflow_attributes][:identifier]
      permitted_params[:internal_workflow_attributes][:name] = find_workflow_name(identifier) if identifier
    end

    # For release candidate workflow
    if permitted_params[:release_candidate_workflow_attributes].present? && permitted_params[:release_candidate_workflow_attributes][:identifier].present?
      identifier = permitted_params[:release_candidate_workflow_attributes][:identifier]
      permitted_params[:release_candidate_workflow_attributes][:name] = find_workflow_name(identifier) if identifier
    end

    # For internal release submissions
    if permitted_params[:internal_release_attributes].present?
      permitted_params[:internal_release_attributes][:submissions_attributes]&.each do |_, submission|
        submission[:submission_external_attributes][:name] = find_submission_name(submission)
      end
    end

    # For beta release submissions
    if permitted_params[:beta_release_attributes].present?
      permitted_params[:beta_release_attributes][:submissions_attributes]&.each do |_, submission|
        submission[:submission_external_attributes][:name] = find_submission_name(submission)
      end
    end

    if permitted_params[:production_release_attributes].present? && permitted_params[:production_release_attributes][:submissions_attributes]["0"][:rollout_enabled] == "true"
      permitted_params[:production_release_attributes][:submissions_attributes]["0"][:rollout_stages] = permitted_params[:production_release_attributes][:submissions_attributes]["0"][:rollout_stages].safe_csv_parse
    end

    permitted_params
  end

  def find_submission_name(submission)
    identifier = submission.dig(:submission_external_attributes, :identifier)
    return unless identifier

    @submission_types.find { |type| type[:type].to_s == submission[:submission_type].to_s }
      &.then { |sub| sub.dig(:channels) }
      &.then { |channels| channels.find { |channel| channel[:id].to_s == identifier } }
      &.then { |channel| channel[:name] }
  end

  def find_workflow_name(identifier)
    @ci_actions.find { |action| action[:id] == identifier }&.dig(:name)
  end
end

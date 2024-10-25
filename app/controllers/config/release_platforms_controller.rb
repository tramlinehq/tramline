class Config::ReleasePlatformsController < SignedInApplicationController
  include Tabbable
  using RefinedString

  before_action :require_write_access!, only: %i[edit update]
  before_action :set_train, only: %i[edit update]
  before_action :set_app_from_train, only: %i[edit update]
  before_action :set_release_platform, only: %i[edit update]
  before_action :set_config, only: %i[edit update]
  before_action :set_train_config_tabs, only: %i[edit update]
  before_action :set_ci_actions, only: %i[edit update]
  before_action :set_submission_types, only: %i[edit update]
  around_action :set_time_zone

  def edit
    @edit_allowed = @train.active_runs.exists?
  end

  def update
    if @config.update(update_config_params)
      redirect_to update_redirect_path, notice: t(".success")
    else
      redirect_to update_redirect_path, flash: {error: @config.errors.full_messages.to_sentence}
    end
  end

  private

  def set_train
    @train = Train.friendly.friendly.find(params[:train_id])
  end

  def set_app_from_train
    @app = @train.app
  end

  def set_release_platform
    @release_platform = @train.release_platforms.find_by(platform: params[:platform_id])
  end

  def set_config
    @config = @release_platform.platform_config
  end

  def set_ci_actions
    @ci_actions = @app.config.ci_cd_workflows
  end

  def set_submission_types
    @submission_types = @config.allowed_pre_prod_submissions
  end

  def config_params
    params.require(:config_release_platform).permit(
      :internal_release_enabled,
      :beta_release_submissions_enabled,
      :production_release_enabled,
      internal_release_attributes: [
        :id, :auto_promote,
        submissions_attributes: [
          :id, :submission_type, :_destroy, :number, :auto_promote, :integrable_id,
          submission_external_attributes: [:id, :identifier, :_destroy]
        ]
      ],
      beta_release_attributes: [
        :id, :auto_promote,
        submissions_attributes: [
          :id, :submission_type, :_destroy, :number, :auto_promote, :integrable_id,
          submission_external_attributes: [:id, :identifier, :_destroy]
        ]
      ],
      release_candidate_workflow_attributes: [
        :id, :identifier, :artifact_name_pattern
      ],
      production_release_attributes: [
        :id,
        submissions_attributes: [
          :id, :submission_type, :_destroy, :rollout_stages, :rollout_enabled
        ]
      ],
      internal_workflow_attributes: [
        :id, :identifier, :_destroy, :artifact_name_pattern
      ]
    )
  end

  # Parse form params and delete parents as necessary
  def update_config_params
    permitted_params = config_params
    internal_enabled = permitted_params[:internal_release_enabled] == "true"
    beta_enabled = permitted_params[:beta_release_submissions_enabled] == "true"
    prod_enabled = permitted_params[:production_release_enabled] == "true"

    if !internal_enabled && permitted_params[:internal_release_attributes].present?
      set_destroy!(permitted_params[:internal_release_attributes])
      set_destroy!(permitted_params[:internal_workflow_attributes])
    end

    if !beta_enabled && permitted_params[:beta_release_attributes].present?
      permitted_params[:beta_release_attributes][:submissions_attributes]&.each do |_, submission|
        set_destroy!(submission)
        set_destroy!(submission[:submission_external_attributes])
      end
    end

    if !prod_enabled && permitted_params[:production_release_attributes].present?
      set_destroy!(permitted_params[:production_release_attributes])
    end

    parse_config_params(permitted_params)
  end

  def parse_config_params(permitted_params)
    update_workflow_name(permitted_params[:internal_workflow_attributes])
    update_workflow_name(permitted_params[:release_candidate_workflow_attributes])
    update_submission_params(permitted_params[:internal_release_attributes])
    update_submission_params(permitted_params[:beta_release_attributes])
    update_production_release_rollout_stages(permitted_params[:production_release_attributes]) if @release_platform.android? && permitted_params[:production_release_attributes].present?

    permitted_params
  end

  def update_workflow_name(workflow_attributes)
    if workflow_attributes&.dig(:identifier).present?
      workflow_attributes[:name] = find_workflow_name(workflow_attributes[:identifier])
    end
  end

  def update_submission_params(release_attributes)
    if release_attributes.present?
      release_attributes[:submissions_attributes]&.each do |_, submission|
        variant = @submission_types[:variants].find { |v| v[:id] == submission[:integrable_id] }
        submission[:integrable_type] = variant[:type]

        ext_sub = find_submission(submission, variant)
        if ext_sub.present?
          submission[:submission_external_attributes][:name] = ext_sub[:name]
          submission[:submission_external_attributes][:internal] = ext_sub[:is_internal]
        end
      end
    end
  end

  def update_production_release_rollout_stages(production_release_attributes)
    submission_attributes = production_release_attributes[:submissions_attributes]["0"]
    if production_release_attributes.present? && submission_attributes[:rollout_enabled] == "true"
      submission_attributes[:rollout_stages] = submission_attributes[:rollout_stages].safe_csv_parse
    end
  end

  def find_workflow_name(identifier)
    @ci_actions.find { |action| action[:id] == identifier }&.dig(:name)
  end

  def find_submission(submission, variant)
    return if variant.blank?
    identifier = submission.dig(:submission_external_attributes, :identifier)
    return unless identifier

    variant[:submissions].find { |type| type[:type].to_s == submission[:submission_type].to_s }
      &.then { |sub| sub.dig(:channels) }
      &.then { |channels| channels.find { |channel| channel[:id].to_s == identifier } }
  end

  def set_destroy!(param)
    param[:_destroy] = "1"
  end

  def update_redirect_path
    edit_app_train_platform_submission_config_path(@app, @train, @release_platform.platform)
  end
end

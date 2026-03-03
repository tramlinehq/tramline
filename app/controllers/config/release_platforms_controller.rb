class Config::ReleasePlatformsController < SignedInApplicationController
  include Tabbable
  using RefinedString
  ConfigUpdater = WebHandlers::UpdateReleasePlatformConfig

  before_action :require_write_access!, only: %i[update test_workflow]
  before_action :set_train, only: %i[edit update refresh_workflows test_workflow]
  before_action :set_app_from_train, only: %i[edit update test_workflow]
  before_action :set_release_platform, only: %i[edit update refresh_workflows test_workflow]
  before_action :set_config, only: %i[edit update test_workflow]
  before_action :set_train_config_tabs, only: %i[edit update]
  before_action :ensure_app_ready, only: %i[edit update]
  before_action :set_ci_actions, only: %i[edit update]
  before_action :set_submission_types, only: %i[edit update]
  around_action :set_time_zone

  def edit
    @edit_allowed = @train.active_runs.exists?
  end

  def update
    updater = ConfigUpdater.new(@config, config_params, @submission_types, @ci_actions, @release_platform)

    if updater.call
      redirect_to update_redirect_path, notice: t(".success")
    else
      error_message = updater.errors.full_messages.to_sentence
      redirect_to update_redirect_path, flash: {error: error_message.presence || "Failed to update configuration."}
    end
  end

  def refresh_workflows
    RefreshWorkflowsJob.perform_async(@train.id)
    redirect_to update_redirect_path, notice: t(".success")
  end

  def test_workflow
    workflow = find_workflow(params[:workflow_kind])

    if workflow&.identifier.blank?
      redirect_to update_redirect_path, flash: {error: t(".not_found")}
      return
    end

    inputs = {
      version_code: "0",
      build_version: "0.0.0-test",
      parameters: workflow.parameters.each_with_object({}) { |p, h| h[p.name] = p.value }
    }

    result = @train.ci_cd_provider.trigger_workflow_run!(workflow.identifier, @train.working_branch, inputs)
    ci_link = result[:ci_link] if result.is_a?(Hash)

    workflow_label = workflow.release_candidate? ? "RC" : "Internal"

    if ci_link.present?
      redirect_to update_redirect_path, flash: {notice_html: t(".success_html", ci_link: ci_link, workflow_kind: workflow_label, workflow_name: workflow.name)}
    else
      redirect_to update_redirect_path, notice: t(".triggered", workflow_kind: workflow_label, workflow_name: workflow.name)
    end
  rescue Installations::Error => e
    redirect_to update_redirect_path, flash: {error: t(".failure", error: e.message)}
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
    @ci_actions = @train.workflows || []
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
        :id, :identifier, :artifact_name_pattern, :build_suffix,
        parameters_attributes: [:id, :name, :value, :_destroy]
      ],
      production_release_attributes: [
        :id,
        submissions_attributes: [
          :id, :submission_type, :_destroy, :rollout_stages, :rollout_enabled, :finish_rollout_in_next_release, :production_form_factor, :automatic_rollout, :auto_start_rollout_after_submission
        ]
      ],
      internal_workflow_attributes: [
        :id, :identifier, :_destroy, :artifact_name_pattern, :build_suffix,
        parameters_attributes: [:id, :name, :value, :_destroy]
      ]
    )
  end

  def find_workflow(kind)
    case kind
    when "release_candidate"
      @config.release_candidate_workflow
    when "internal"
      @config.internal_workflow
    end
  end

  def update_redirect_path
    edit_app_train_platform_submission_config_path(@app, @train, @release_platform.platform)
  end
end

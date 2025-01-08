class AppConfigsController < SignedInApplicationController
  using RefinedString

  around_action :set_time_zone
  before_action :require_write_access!, only: %i[edit update]
  before_action :set_integration_category, only: %i[edit]
  before_action :set_app_config, only: %i[edit update]

  BUGSNAG_CONFIG_PARAMS = [:bugsnag_ios_project_id, :bugsnag_ios_release_stage, :bugsnag_android_project_id, :bugsnag_android_release_stage].freeze

  def edit
    respond_to do |format|
      format.html do |variant|
        variant.turbo_frame do
          pick_category
          render edit_category_partial
        end
      end

      format.turbo_stream do
        pick_category
        render edit_category_partial
      end
    end
  end

  def update
    if @config.update(parsed_app_config_params)
      redirect_to app_path(@app), notice: "App Config was successfully updated."
    else
      redirect_back fallback_location: edit_app_path(@app), flash: {error: @config.errors.full_messages.to_sentence}
    end
  end

  private

  def pick_category
    case @integration_category
    when Integration.categories[:version_control] then configure_version_control
    when Integration.categories[:ci_cd] then configure_ci_cd
    when Integration.categories[:monitoring] then configure_monitoring
    when Integration.categories[:build_channel] then configure_build_channel
    when Integration.categories[:project_management] then configure_project_management
    else raise "Invalid integration category."
    end
  end

  def edit_category_partial
    "app_configs/#{@integration_category}"
  end

  def configure_version_control
    set_code_repositories if further_setup_by_category?.dig(:version_control, :further_setup)
  end

  def configure_ci_cd
    set_ci_cd_projects if further_setup_by_category?.dig(:ci_cd, :further_setup)
  end

  def configure_build_channel
    set_firebase_apps if further_setup_by_category?.dig(:build_channel, :further_setup)
  end

  def configure_monitoring
    set_monitoring_projects if further_setup_by_category?.dig(:monitoring, :further_setup)
  end

  def configure_project_management
    set_jira_projects if further_setup_by_category?.dig(:project_management, :further_setup)
  end

  def set_app_config
    @config = AppConfig.find_or_initialize_by(app: @app)
  end

  def app_config_params
    params
      .require(:app_config)
      .permit(
        :code_repository,
        :bitrise_project_id,
        :firebase_android_config,
        :firebase_ios_config,
        :bugsnag_ios_release_stage,
        :bugsnag_ios_project_id,
        :bugsnag_android_release_stage,
        :bugsnag_android_project_id,
        :bitbucket_workspace,
        jira_config: {
          selected_projects: [],
          project_configs: {},
          release_tracking: [:track_tickets, :auto_transition],
          release_filters: [[:type, :value]]
        }
      )
  end

  def parsed_app_config_params
    app_config_params
      .merge(code_repository: app_config_params[:code_repository]&.safe_json_parse)
      .merge(bitrise_project_id: app_config_params[:bitrise_project_id]&.safe_json_parse)
      .merge(bugsnag_config(app_config_params.slice(*BUGSNAG_CONFIG_PARAMS)))
      .merge(firebase_ios_config: app_config_params[:firebase_ios_config]&.safe_json_parse)
      .merge(firebase_android_config: app_config_params[:firebase_android_config]&.safe_json_parse)
      .merge(jira_config: parse_jira_config(app_config_params[:jira_config]))
      .except(*BUGSNAG_CONFIG_PARAMS)
      .compact
  end

  def set_ci_cd_projects
    @ci_cd_apps = @app.ci_cd_provider.setup
  end

  def set_monitoring_projects
    @monitoring_projects = @app.monitoring_provider.setup
  end

  def set_firebase_apps
    config = @app.integrations.firebase_build_channel_provider.setup
    @firebase_android_apps, @firebase_ios_apps = config[:android], config[:ios]
  end

  def set_code_repositories
    @workspaces = @app.vcs_provider.workspaces || []
    workspace = params[:workspace] || @workspaces.first
    @code_repositories = @app.vcs_provider.repos(workspace)
  end

  def set_integration_category
    if Integration.categories.key?(params[:integration_category])
      @integration_category = params[:integration_category]
    else
      redirect_to app_path(@app), flash: {notice: "Invalid integration category."}
    end
  end

  def set_jira_projects
    provider = @app.integrations.project_management_provider
    @jira_data = provider.setup

    @config.jira_config = {} if @config.jira_config.nil?

    @config.jira_config = {
      "selected_projects" => @config.jira_config["selected_projects"] || [],
      "project_configs" => @config.jira_config["project_configs"] || {},
      "release_tracking" => @config.jira_config["release_tracking"] || {
        "track_tickets" => false,
        "auto_transition" => false
      },
      "release_filters" => @config.jira_config["release_filters"] || []
    }

    @jira_data[:projects]&.each do |project|
      project_key = project["key"]
      statuses = @jira_data[:project_statuses][project_key]

      done_states = statuses&.select { |status| status["name"] == "Done" }&.pluck("name") || []

      @config.jira_config["project_configs"][project_key] ||= {
        "done_states" => done_states
      }
    end

    @config.save! if @config.changed?
    @current_jira_config = @config.jira_config.with_indifferent_access
  end

  def parse_jira_config(config)
    return {} if config.blank?

    {
      selected_projects: Array(config[:selected_projects]),
      project_configs: config[:project_configs]&.transform_values do |project_config|
        {
          done_states: Array(project_config[:done_states])&.reject(&:blank?),
          custom_done_states: Array(project_config[:custom_done_states])&.reject(&:blank?)
        }
      end || {},
      release_tracking: {
        track_tickets: ActiveModel::Type::Boolean.new.cast(config.dig(:release_tracking, :track_tickets)),
        auto_transition: ActiveModel::Type::Boolean.new.cast(config.dig(:release_tracking, :auto_transition))
      },
      release_filters: config[:release_filters]&.values&.filter_map do |filter|
        next if filter[:type].blank? || filter[:value].blank?
        {
          "type" => filter[:type],
          "value" => filter[:value]
        }
      end || []
    }
  end

  def bugsnag_config(config_params)
    config = {}

    if config_params[:bugsnag_ios_release_stage].present?
      config[:bugsnag_ios_config] = {
        project_id: config_params[:bugsnag_ios_project_id].safe_json_parse,
        release_stage: config_params[:bugsnag_ios_release_stage]
      }
    end

    if config_params[:bugsnag_android_release_stage].present?
      config[:bugsnag_android_config] = {
        project_id: config_params[:bugsnag_android_project_id].safe_json_parse,
        release_stage: config_params[:bugsnag_android_release_stage]
      }
    end

    config
  end

  def further_setup_by_category?
    @further_setup_by_category ||= @config.further_setup_by_category?
  end
end

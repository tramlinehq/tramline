class ProjectManagement::ConfigsController < SignedInApplicationController
  using RefinedString

  before_action :require_write_access!, only: %i[update]
  before_action :set_project_management_integration, only: %i[edit update]
  around_action :set_time_zone

  def edit
    respond_to do |format|
      format.html do |variant|
        variant.turbo_frame do
          set_project_management_data if @integration.further_setup?
          render "project_management/configs/edit"
        end
      end

      format.turbo_stream do
        set_project_management_data if @integration.further_setup?
        render "project_management/configs/edit"
      end
    end
  end

  def update
    if @integration.update(project_management_config_params)
      redirect_to app_path(@app), notice: "#{@integration.display} configuration was successfully updated."
    else
      redirect_back fallback_location: edit_app_path(@app), flash: {error: @integration.errors.full_messages.to_sentence}
    end
  end

  private

  def set_project_management_integration
    @integration = @app.integrations.project_management_provider
    unless @integration
      redirect_to app_path(@app), flash: {error: "Project management integration not found."}
    end
  end

  def project_management_config_params
    case @integration.class.name
    when 'JiraIntegration'
      {
        project_config: parse_jira_config(params[:jira_integration][:project_config])
      }
    when 'LinearIntegration'
      {
        team_config: parse_linear_config(params[:linear_integration][:team_config])
      }
    else
      {}
    end
  end

  def set_project_management_data
    case @integration.class.name
    when 'JiraIntegration'
      set_jira_projects
    when 'LinearIntegration'
      set_linear_projects
    end
  end

  def set_jira_projects
    provider = @app.integrations.project_management_provider
    @jira_data = provider.setup

    @integration.project_config = {} if @integration.project_config.nil?
    @integration.project_config = {
      "selected_projects" => @integration.project_config["selected_projects"] || [],
      "project_configs" => @integration.project_config["project_configs"] || {},
      "release_tracking" => @integration.project_config["release_tracking"] || {
        "track_tickets" => false,
        "auto_transition" => false
      },
      "release_filters" => @integration.project_config["release_filters"] || []
    }

    @jira_data[:projects]&.each do |project|
      project_key = project["key"]
      statuses = @jira_data[:project_statuses][project_key]
      done_states = statuses&.select { |status| status["name"] == "Done" }&.pluck("name") || []

      @integration.project_config["project_configs"][project_key] ||= {
        "done_states" => done_states
      }
    end

    @integration.save! if @integration.changed?
    @current_jira_config = @integration.project_config.with_indifferent_access
  end

  def set_linear_projects
    provider = @app.integrations.project_management_provider
    @linear_data = provider.setup

    @integration.team_config = {} if @integration.team_config.nil?
    @integration.team_config = {
      "selected_teams" => @integration.team_config["selected_teams"] || [],
      "team_configs" => @integration.team_config["team_configs"] || {},
      "release_filters" => @integration.team_config["release_filters"] || []
    }

    @linear_data[:teams]&.each do |team|
      team_id = team["id"]
      workflow_states = @linear_data[:workflow_states]
      done_states = workflow_states&.select { |state| state["type"] == "completed" }&.pluck("name") || []

      @integration.team_config["team_configs"][team_id] ||= {
        "done_states" => done_states
      }
    end

    @integration.save! if @integration.changed?
    @current_linear_config = @integration.team_config.with_indifferent_access
  end

  def parse_jira_config(config)
    return {} if config.blank?

    {
      selected_projects: Array(config[:selected_projects]),
      project_configs: config[:project_configs]&.transform_values do |project_config|
        {
          done_states: Array(project_config[:done_states]).compact_blank,
          custom_done_states: Array(project_config[:custom_done_states]).compact_blank
        }
      end || {},
      release_tracking: {
        track_tickets: ActiveModel::Type::Boolean.new.cast(config.dig(:release_tracking, :track_tickets)),
        auto_transition: ActiveModel::Type::Boolean.new.cast(config.dig(:release_tracking, :auto_transition))
      },
      release_filters: config[:release_filters]&.values&.filter_map do |filter|
        next if filter[:type].blank? || filter[:value].blank? || filter[:_destroy] == "1"
        {
          "type" => filter[:type],
          "value" => filter[:value]
        }
      end || []
    }
  end

  def parse_linear_config(config)
    return {} if config.blank?

    {
      selected_teams: Array(config[:selected_teams]),
      team_configs: config[:team_configs]&.transform_values do |team_config|
        {
          done_states: Array(team_config[:done_states]).compact_blank,
          custom_done_states: Array(team_config[:custom_done_states]).compact_blank
        }
      end || {},
      release_filters: config[:release_filters]&.values&.filter_map do |filter|
        next if filter[:type].blank? || filter[:value].blank? || filter[:_destroy] == "1"
        {
          "type" => filter[:type],
          "value" => filter[:value]
        }
      end || []
    }
  end
end
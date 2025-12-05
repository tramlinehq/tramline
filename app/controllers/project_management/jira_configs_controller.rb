class ProjectManagement::JiraConfigsController < SignedInApplicationController
  before_action :require_write_access!
  before_action :set_jira_integration

  def edit
    set_jira_projects

    respond_to do |format|
      format.html do |variant|
        variant.turbo_frame { render :edit }
      end
    end
  end

  def update
    if @jira_integration.update(parsed_jira_config_params)
      redirect_to app_path(@app), notice: t(".success")
    else
      redirect_back fallback_location: app_integrations_path(@app),
        flash: {error: @jira_integration.errors.full_messages.to_sentence}
    end
  end

  private

  def set_jira_integration
    project_management_integration = @app.project_management_provider
    unless project_management_integration&.is_a?(JiraIntegration)
      redirect_to app_integrations_path(@app), flash: {error: "Jira integration not found."}
    end
    @jira_integration = project_management_integration
  end

  def set_jira_projects
    @jira_data = @jira_integration.setup

    # Initialize project_config structure
    @jira_integration.project_config = {} if @jira_integration.project_config.blank?
    @jira_integration.project_config = {
      "selected_projects" => @jira_integration.project_config["selected_projects"] || [],
      "project_configs" => @jira_integration.project_config["project_configs"] || {},
      "release_tracking" => @jira_integration.project_config["release_tracking"] || {
        "track_tickets" => false,
        "auto_transition" => false
      },
      "release_filters" => @jira_integration.project_config["release_filters"] || []
    }

    # Initialize project configs
    @jira_data[:projects]&.each do |project|
      project_key = project["key"]
      statuses = @jira_data[:project_statuses][project_key]
      done_states = statuses&.select { |status| status["name"] == "Done" }&.pluck("name") || []

      @jira_integration.project_config["project_configs"][project_key] ||= {
        "done_states" => done_states
      }
    end

    @jira_integration.save! if @jira_integration.changed?
    @current_jira_config = @jira_integration.project_config.with_indifferent_access
  end

  def parsed_jira_config_params
    jira_config_params = params.require(:jira_integration)
      .permit(
        project_config: {
          selected_projects: [],
          project_configs: {},
          release_tracking: [:track_tickets, :auto_transition],
          release_filters: [[:type, :value, :_destroy]]
        }
      )

    jira_config_params.merge(project_config: parse_jira_config(jira_config_params[:project_config]))
  end

  def parse_jira_config(config_params)
    return {} if config_params.blank?

    {
      selected_projects: Array(config_params[:selected_projects]),
      project_configs: config_params[:project_configs]&.transform_values do |project_config|
        {
          done_states: Array(project_config[:done_states]).compact_blank
        }
      end || {},
      release_tracking: {
        track_tickets: ActiveModel::Type::Boolean.new.cast(config_params.dig(:release_tracking, :track_tickets)),
        auto_transition: ActiveModel::Type::Boolean.new.cast(config_params.dig(:release_tracking, :auto_transition))
      },
      release_filters: config_params[:release_filters]&.values&.filter_map do |filter|
        next if filter[:type].blank? || filter[:value].blank? || filter[:_destroy] == "1"
        {
          "type" => filter[:type],
          "value" => filter[:value]
        }
      end || []
    }
  end
end

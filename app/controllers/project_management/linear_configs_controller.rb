class ProjectManagement::LinearConfigsController < SignedInApplicationController
  using RefinedString

  before_action :require_write_access!
  before_action :set_app
  before_action :set_linear_integration
  around_action :set_time_zone

  def edit
    set_linear_projects

    respond_to do |format|
      format.html do |variant|
        variant.turbo_frame { render :edit }
      end
    end
  end

  def update
    if @linear_integration.update(parsed_linear_config_params)
      redirect_to app_integrations_path(@app), notice: t(".success")
    else
      redirect_back fallback_location: app_integrations_path(@app),
        flash: {error: @linear_integration.errors.full_messages.to_sentence}
    end
  end

  private

  def set_app
    @app = current_organization.apps.friendly.find(params[:app_id])
  end

  def set_linear_integration
    project_management_integration = @app.project_management_provider
    unless project_management_integration&.is_a?(LinearIntegration)
      redirect_to app_integrations_path(@app), flash: {error: "Linear integration not found."}
    end
    @linear_integration = project_management_integration
  end

  def set_linear_projects
    @linear_data = @linear_integration.setup

    # Initialize project_config structure
    @linear_integration.project_config = {} if @linear_integration.project_config.blank?
    @linear_integration.project_config = {
      "selected_teams" => @linear_integration.project_config["selected_teams"] || [],
      "team_configs" => @linear_integration.project_config["team_configs"] || {},
      "release_filters" => @linear_integration.project_config["release_filters"] || []
    }

    # Initialize team configs
    @linear_data[:teams]&.each do |team|
      team_id = team["id"]
      workflow_states = @linear_data[:workflow_states]
      done_states = workflow_states&.select { |state| state["type"] == "completed" }&.pluck("name") || []

      @linear_integration.project_config["team_configs"][team_id] ||= {
        "done_states" => done_states
      }
    end

    @linear_integration.save! if @linear_integration.changed?
    @current_linear_config = @linear_integration.project_config.with_indifferent_access
  end

  def parsed_linear_config_params
    linear_config_params = params.require(:linear_integration)
      .permit(
        project_config: {
          selected_teams: [],
          team_configs: {},
          release_filters: [[:type, :value, :_destroy]]
        }
      )
    linear_config_params.merge(project_config: parse_linear_config(linear_config_params[:project_config]))
  end

  def parse_linear_config(config_params)
    return {} if config_params.blank?

    {
      selected_teams: Array(config_params[:selected_teams]),
      team_configs: config_params[:team_configs]&.transform_values do |team_config|
        {
          done_states: Array(team_config[:done_states]).compact_blank,
          custom_done_states: Array(team_config[:custom_done_states]).compact_blank
        }
      end || {},
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

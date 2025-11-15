# == Schema Information
#
# Table name: jira_integrations
#
#  id                  :uuid             not null, primary key
#  oauth_access_token  :string
#  oauth_refresh_token :string
#  organization_name   :string
#  organization_url    :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  cloud_id            :string           indexed
#
class JiraIntegration < ApplicationRecord
  has_paper_trail
  using RefinedHash
  include Linkable
  include Vaultable
  include Providable
  include Displayable
  include Loggable

  encrypts :oauth_access_token, deterministic: true
  encrypts :oauth_refresh_token, deterministic: true

  BASE_INSTALLATION_URL = Addressable::Template.new("https://auth.atlassian.com/authorize{?params*}")
  PUBLIC_ICON = "https://storage.googleapis.com/tramline-public-assets/jira_small.png".freeze
  VALID_FILTER_TYPES = %w[label fix_version].freeze
  API = Installations::Jira::Api

  USER_INFO_TRANSFORMATIONS = {
    id: :accountId,
    name: :displayName,
    email: :emailAddress
  }.freeze

  PROJECT_TRANSFORMATIONS = {
    id: :id,
    key: :key,
    name: :name,
    description: :description,
    url: :self
  }.freeze

  STATUS_TRANSFORMATIONS = {
    id: :id,
    name: :name,
    category: [:statusCategory, :key]
  }.freeze

  TICKET_TRANSFORMATIONS = {
    key: :key,
    summary: [:fields, :summary],
    status: [:fields, :status, :name],
    assignee: [:fields, :assignee, :displayName],
    labels: [:fields, :labels],
    fix_versions: [:fields, :fixVersions]
  }.freeze

  attr_accessor :code, :available_resources
  delegate :app, to: :integration
  delegate :cache, to: Rails
  validates :cloud_id, presence: true

  def install_path
    BASE_INSTALLATION_URL
      .expand(params: {
        client_id: creds.integrations.jira.client_id,
        audience: "api.atlassian.com",
        redirect_uri: redirect_uri,
        response_type: :code,
        prompt: "consent",
        scope: "read:jira-work write:jira-work read:jira-user offline_access",
        state: integration.installation_state
      }).to_s
  end

  # if the user has access to only one organization, then set the cloud_id and assume the access is complete
  # otherwise, set available_resources so that the user can select the right cloud_id and then eventually complete the access
  def complete_access
    return false if code.blank? || redirect_uri.blank?

    resources, tokens = API.get_accessible_resources(code, redirect_uri)
    set_tokens(tokens)

    # access is already complete if cloud_id is already set
    # just set the metadata and move on
    if cloud_id.present?
      resource = resources.find { |resource| resource["id"] == cloud_id }
      return false if resource.nil?
      self.organization_url = resource["url"]
      self.organization_name = resource["name"]
      return true
    end

    if resources.length == 1
      resource = resources.first
      self.cloud_id = resource["id"]
      self.organization_url = resource["url"]
      self.organization_name = resource["name"]
      true
    else
      @available_resources = resources
      false
    end
  end

  def installation
    API.new(oauth_access_token, cloud_id)
  end

  def to_s = "jira"

  def creatable? = false

  def connectable? = true

  def store? = false

  def project_link = nil

  def further_setup? = true

  def public_icon_img
    PUBLIC_ICON
  end

  def setup
    return {} if cloud_id.blank?

    with_api_retries do
      projects_result = fetch_projects
      projects = projects_result.dig(:projects)
      return {} if projects.empty?

      statuses_data = fetch_project_statuses(projects)
      {
        projects: projects,
        project_statuses: statuses_data
      }
    end
  rescue Installations::Error => e
    elog("Failed to fetch Jira setup data for cloud_id #{cloud_id}: #{e}", level: :warn)
    {}
  end

  def metadata = cloud_id

  def connection_data
    return unless integration.metadata

    if organization_name.present?
      "Organization: #{organization_name} (#{integration.metadata})"
    else
      "Cloud ID: #{integration.metadata}"
    end
  end

  def fetch_tickets_for_release
    return [] if app.config.jira_config.blank?

    project_key = app.config.jira_config["selected_projects"]&.last
    release_filters = app.config.jira_config["release_filters"]
    return [] if project_key.blank? || release_filters.blank?

    with_api_retries do
      response = api.search_tickets_by_filters(project_key, release_filters, TICKET_TRANSFORMATIONS)
      issues = response["issues"]
      return [] if issues.blank?
      issues
    end
  rescue Installations::Error => e
    elog("Failed to fetch Jira tickets for release: #{e}", level: :warn)
    []
  end

  def ticket_url(ticket_id)
    return if organization_url.blank? || ticket_id.blank?
    template = Addressable::Template.new("#{organization_url}/browse/{ticket}")
    template.expand(ticket: ticket_id).to_s
  end

  def display
    "Jira"
  end

  private

  MAX_RETRY_ATTEMPTS = 2
  RETRYABLE_ERRORS = [:server_error]

  def with_api_retries(attempt: 0, &)
    yield
  rescue Installations::Error => ex
    raise ex if attempt >= MAX_RETRY_ATTEMPTS
    next_attempt = attempt + 1

    if %i[token_expired token_refresh_failure].include?(ex.reason)
      reset_tokens!
      return with_api_retries(attempt: next_attempt, &)
    end

    if RETRYABLE_ERRORS.include?(ex.reason)
      return with_api_retries(attempt: next_attempt, &)
    end

    raise ex
  end

  def reset_tokens!
    tokens = API.oauth_refresh_token(oauth_refresh_token, redirect_uri)

    if tokens.nil? || tokens.access_token.blank? || tokens.refresh_token.blank?
      raise Installations::Error::TokenRefreshFailure
    end

    set_tokens(tokens)
    save!

    reload
  end

  def set_tokens(tokens)
    self.oauth_access_token = tokens.access_token
    self.oauth_refresh_token = tokens.refresh_token
  end

  def redirect_uri
    jira_callback_url(link_params)
  end

  def api
    @api ||= API.new(oauth_access_token, cloud_id)
  end

  def fetch_projects
    projects = {projects: []}
    return projects if cloud_id.blank?

    with_api_retries do
      projects[:projects] = api.projects(PROJECT_TRANSFORMATIONS)
      projects
    end
  rescue Installations::Error => e
    elog("Failed to fetch Jira projects for cloud_id #{cloud_id}: #{e}", level: :warn)
    projects
  end

  def fetch_project_statuses(projects)
    return {} if cloud_id.blank? || projects.blank?

    with_api_retries do
      statuses = {}
      projects.each do |project|
        project_statuses = api.project_statuses(project["key"], STATUS_TRANSFORMATIONS)
        statuses[project["key"]] = project_statuses
      end
      statuses
    end
  rescue Installations::Error => e
    elog("Failed to fetch Jira project statuses for cloud_id #{cloud_id}: #{e}", level: :warn)
    {}
  end
end

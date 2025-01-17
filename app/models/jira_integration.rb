# == Schema Information
#
# Table name: jira_integrations
#
#  id                  :uuid             not null, primary key
#  oauth_access_token  :string
#  oauth_refresh_token :string
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

  encrypts :oauth_access_token, deterministic: true
  encrypts :oauth_refresh_token, deterministic: true

  BASE_INSTALLATION_URL =
    Addressable::Template.new("https://auth.atlassian.com/authorize{?params*}")
  PUBLIC_ICON = "https://storage.googleapis.com/tramline-public-assets/jira_small.png".freeze
  VALID_FILTER_TYPES = %w[label fix_version].freeze

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

  attr_accessor :code, :callback_url, :available_resources
  before_validation :complete_access, on: :create
  delegate :app, to: :integration
  delegate :cache, to: Rails

  validates :cloud_id, presence: true
  validate :validate_release_filters, if: -> { app.config.jira_config&.dig("release_filters").present? }

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

  def complete_access
    return false if code.blank? || (callback_url.blank? && redirect_uri.blank?)

    resources, tokens = Installations::Jira::Api.get_accessible_resources(code, callback_url || redirect_uri)
    set_tokens(tokens)

    if resources.length == 1
      self.cloud_id = resources.first["id"]
      true
    else
      @available_resources = resources
      false
    end
  end

  def installation
    Installations::Jira::Api.new(oauth_access_token, cloud_id)
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
      return {} if projects_result[:projects].empty?

      statuses_data = fetch_project_statuses(projects_result[:projects])

      {
        projects: projects_result[:projects],
        project_statuses: statuses_data
      }
    end
  rescue => e
    Rails.logger.error("Failed to fetch Jira setup data for cloud_id #{cloud_id}: #{e.message}")
    {}
  end

  def metadata
    with_api_retries { installation.user_info(USER_INFO_TRANSFORMATIONS) }
  end

  def connection_data
    return unless integration.metadata
    "Added by user: #{integration.metadata["name"]} (#{integration.metadata["email"]})"
  end

  def fetch_tickets_for_release
    return [] if app.config.jira_config.blank?

    project_key = app.config.jira_config["selected_projects"]&.last
    release_filters = app.config.jira_config["release_filters"]
    return [] if project_key.blank? || release_filters.blank?

    with_api_retries do
      response = api.search_tickets_by_filters(
        project_key,
        release_filters,
        TICKET_TRANSFORMATIONS
      )
      return [] if response["issues"].blank?

      response["issues"]
    end
  rescue => e
    Rails.logger.error("Failed to fetch Jira tickets for release: #{e.message}")
    []
  end

  def display
    "Jira"
  end

  private

  MAX_RETRY_ATTEMPTS = 2
  RETRYABLE_ERRORS = []

  def with_api_retries(attempt: 0, &)
    yield
  rescue Installations::Error => ex
    raise ex if attempt >= MAX_RETRY_ATTEMPTS
    next_attempt = attempt + 1

    if ex.reason == :token_expired
      reset_tokens!
      return with_api_retries(attempt: next_attempt, &)
    end

    if RETRYABLE_ERRORS.include?(ex.reason)
      return with_api_retries(attempt: next_attempt, &)
    end

    raise ex
  end

  def reset_tokens!
    set_tokens(Installations::Jira::Api.oauth_refresh_token(oauth_refresh_token, redirect_uri))
    save!
  end

  def set_tokens(tokens)
    return unless tokens

    self.oauth_access_token = tokens.access_token
    self.oauth_refresh_token = tokens.refresh_token
  end

  def redirect_uri
    jira_callback_url(link_params)
  end

  def api
    @api ||= Installations::Jira::Api.new(oauth_access_token, cloud_id)
  end

  def fetch_projects
    return {projects: []} if cloud_id.blank?
    with_api_retries do
      response = api.projects(PROJECT_TRANSFORMATIONS)
      {projects: response}
    end
  rescue => e
    Rails.logger.error("Failed to fetch Jira projects for cloud_id #{cloud_id}: #{e.message}")
    {projects: []}
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
  rescue => e
    Rails.logger.error("Failed to fetch Jira project statuses for cloud_id #{cloud_id}: #{e.message}")
    {}
  end

  def validate_release_filters
    return if app.config.jira_config&.dig("release_filters").blank?

    app.config.jira_config["release_filters"].each do |filter|
      unless filter.is_a?(Hash) && VALID_FILTER_TYPES.include?(filter["type"]) && filter["value"].present?
        errors.add(:release_filters, "must contain valid type and value")
      end
    end
  end
end

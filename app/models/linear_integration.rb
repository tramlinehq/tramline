# == Schema Information
#
# Table name: linear_integrations
#
#  id                  :uuid             not null, primary key
#  oauth_access_token  :string
#  oauth_refresh_token :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  organization_id     :string           indexed
#
class LinearIntegration < ApplicationRecord
  has_paper_trail
  using RefinedHash
  include Linkable
  include Vaultable
  include Providable
  include Displayable

  encrypts :oauth_access_token, deterministic: true
  encrypts :oauth_refresh_token, deterministic: true

  BASE_INSTALLATION_URL = Addressable::Template.new("https://linear.app/oauth/authorize{?params*}")
  PUBLIC_ICON = "https://storage.googleapis.com/tramline-public-assets/linear_small.png".freeze
  VALID_FILTER_TYPES = %w[label state].freeze
  API = Installations::Linear::Api

  USER_INFO_TRANSFORMATIONS = {
    id: :id,
    name: :name,
    email: :email
  }.freeze

  TEAM_TRANSFORMATIONS = {
    id: :id,
    key: :key,
    name: :name,
    description: :description
  }.freeze

  WORKFLOW_STATE_TRANSFORMATIONS = {
    id: :id,
    name: :name,
    type: :type
  }.freeze

  ISSUE_TRANSFORMATIONS = {
    id: :id,
    identifier: :identifier,
    title: :title,
    state: [:state, :name],
    assignee: [:assignee, :name],
    labels: [:labels, :nodes]
  }.freeze

  attr_accessor :code, :available_organizations
  delegate :app, to: :integration
  delegate :cache, to: Rails
  validates :organization_id, presence: true

  def install_path
    BASE_INSTALLATION_URL
      .expand(params: {
        client_id: creds.integrations.linear.client_id,
        redirect_uri: redirect_uri,
        response_type: :code,
        scope: "read",
        state: integration.installation_state
      }).to_s
  end

  def complete_access
    return false if code.blank? || redirect_uri.blank?

    tokens = API.get_access_token(code, redirect_uri)
    set_tokens(tokens)

    return true if organization_id.present?

    organizations = API.get_organizations(oauth_access_token)

    if organizations.length >= 1
      self.organization_id = organizations.first["id"]
      true
    else
      false
    end
  end

  def installation
    API.new(oauth_access_token)
  end

  def to_s = "linear"

  def creatable? = false

  def connectable? = true

  def store? = false

  def project_link = nil

  def further_setup? = true

  def public_icon_img
    PUBLIC_ICON
  end

  def setup
    return {} if organization_id.blank?

    with_api_retries do
      teams_result = fetch_teams
      return {} if teams_result[:teams].empty?

      workflow_states_data = fetch_workflow_states
      {
        teams: teams_result[:teams],
        workflow_states: workflow_states_data
      }
    end
  rescue Installations::Error => e
    elog("Failed to fetch Linear setup data for organization_id #{organization_id}: #{e}", level: :warn)
    {}
  end

  def metadata = organization_id

  def connection_data
    "Organization ID: #{integration.metadata}" if integration.metadata
  end

  def fetch_issues_for_release
    return [] if app.config.linear_config.blank?

    team_id = app.config.linear_config["selected_teams"]&.last
    release_filters = app.config.linear_config["release_filters"]
    return [] if team_id.blank? || release_filters.blank?

    with_api_retries do
      response = api.search_issues_by_filters(team_id, release_filters, ISSUE_TRANSFORMATIONS)
      issues = response["issues"]
      return [] if issues.blank?
      issues
    end
  rescue Installations::Error => e
    elog("Failed to fetch Linear issues for release: #{e}", level: :warn)
    []
  end

  def display
    "Linear"
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
    linear_callback_url(link_params)
  end

  def api
    @api ||= API.new(oauth_access_token)
  end

  def fetch_teams
    teams = {teams: []}
    return teams if organization_id.blank?

    with_api_retries do
      teams[:teams] = api.teams(TEAM_TRANSFORMATIONS)
      teams
    end
  rescue Installations::Error => e
    elog("Failed to fetch Linear teams data for organization_id #{organization_id}: #{e.message}", level: :warn)
    teams
  end

  def fetch_workflow_states
    return {} if organization_id.blank?
    with_api_retries { api.workflow_states(WORKFLOW_STATE_TRANSFORMATIONS) }
  rescue Installations::Error => e
    elog("Failed to fetch Linear workflow states for organization_id #{organization_id}: #{e}", level: :warn)
    {}
  end
end

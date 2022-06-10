class GithubIntegration < ApplicationRecord
  has_paper_trail

  include Vaultable
  include Rails.application.routes.url_helpers

  has_one :integration, as: :providable

  BASE_INSTALLATION_URL =
    Addressable::Template.new("https://github.com/apps/{app_name}/installations/new{?params*}")

  def install_path
    raise Integration::IntegrationNotImplemented, "We don't support that yet!" unless integration.version_control? || integration.ci_cd?

    BASE_INSTALLATION_URL
      .expand(app_name: creds.integrations.github.app_name, params: {
                state: integration.installation_state
              }).to_s
  end

  def workflows
    [] unless integration.ci_cd?
    Installations::Github::Api.new(installation_id).list_workflows(app_config.code_repository.values.first)
  end

  def repos
    Installations::Github::Api.new(installation_id).list_repos
  end

  def events_url
    github_events_url(integration.app.id, installation_id)
  end

  def app_config
    integration.app.config
  end

  def to_s
    "github"
  end

  def creatable?
    false
  end

  def connectable?
    true
  end
end

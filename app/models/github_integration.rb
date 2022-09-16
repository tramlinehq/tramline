class GithubIntegration < ApplicationRecord
  has_paper_trail

  include Vaultable
  include Providable
  include Rails.application.routes.url_helpers

  BASE_INSTALLATION_URL =
    Addressable::Template.new("https://github.com/apps/{app_name}/installations/new{?params*}")

  def install_path
    unless integration.version_control? || integration.ci_cd?
      raise Integration::IntegrationNotImplemented, "We don't support that yet!"
    end

    BASE_INSTALLATION_URL
      .expand(app_name: creds.integrations.github.app_name, params: {
        state: integration.installation_state
      }).to_s
  end

  def workflows
    return [] unless integration.ci_cd?
    installation.list_workflows(app_config.code_repository_name)
  end

  def repos
    installation.list_repos
  end

  # @return [Installation::Github::Api]
  def installation
    Installations::Github::Api.new(installation_id)
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

  def branch_url(repo, branch_name)
    "https://github.com/#{repo}/tree/#{branch_name}"
  end

  def tag_url(repo, tag_name)
    "https://github.com/#{repo}/releases/tag/#{tag_name}"
  end
end

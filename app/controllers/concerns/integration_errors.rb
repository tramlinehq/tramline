module IntegrationErrors
  extend ActiveSupport::Concern
  include Loggable

  PROVIDER_NAMES = {
    "Installations::Apple::AppStoreConnect::Error" => "App Store Connect",
    "Installations::Bitbucket::Error" => "Bitbucket",
    "Installations::Crashlytics::Error" => "Crashlytics",
    "Installations::Github::Error" => "GitHub",
    "Installations::Gitlab::Error" => "GitLab",
    "Installations::Google::Firebase::Error" => "Firebase",
    "Installations::Google::PlayDeveloper::Error" => "Google Play",
    "Installations::Google::VertexAi::Error" => "Vertex AI",
    "Installations::Jira::Error" => "Jira",
    "Installations::Linear::Error" => "Linear",
    "Installations::Teamcity::Error" => "TeamCity"
  }.freeze

  included do
    rescue_from Installations::Error, with: :integration_error
  end

  private

  def integration_error(error)
    elog(error, level: :warn)
    redirect_to integration_error_return_path, flash: {error: integration_error_message(error)}
  end

  def integration_error_message(error)
    provider = PROVIDER_NAMES.fetch(error.class.name) { t("errors.messages.integration_failure.any_provider") }

    # an error raised without a message reports its class name as the message
    if error.message.blank? || error.message == error.class.name
      t("errors.messages.integration_failure.unknown", provider:)
    else
      t("errors.messages.integration_failure.known", provider:, error: error.message)
    end
  end

  # A page that failed to load must not be sent back to itself.
  def integration_error_return_path
    candidates = [url_from(request.referer)]
    candidates << app_path(@app) if @app&.persisted?
    candidates.compact.find { |url| !request.get? || URI.parse(url).path != request.path } || root_path
  rescue URI::InvalidURIError
    root_path
  end
end

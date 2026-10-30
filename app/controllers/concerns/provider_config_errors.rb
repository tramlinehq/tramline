module ProviderConfigErrors
  extend ActiveSupport::Concern
  include Loggable

  PROVIDER_NAMES = {
    "bitbucket_configs" => "Bitbucket",
    "gitlab_configs" => "GitLab"
  }.freeze

  included do
    rescue_from Installations::Error, with: :render_provider_config_error
  end

  private

  def render_provider_config_error(error)
    elog(error, level: :warn)
    alert = AlertComponent.new(type: :error, title: provider_config_error_message(error), full_screen: false)

    respond_to do |format|
      format.html { render EnhancedTurboFrameComponent.new(provider_config_frame_id).with_content(alert.render_in(view_context)) }
      format.turbo_stream { render turbo_stream: turbo_stream.update(provider_config_frame_id, alert) }
    end
  end

  def provider_config_error_message(error)
    provider_name = PROVIDER_NAMES.fetch(controller_name)

    if error.reason == :token_refresh_failure
      "The connection to #{provider_name} has expired. Re-authorize it from the integrations page and try again."
    else
      "Could not load data from #{provider_name}. Please try again in a bit."
    end
  end

  def provider_config_frame_id
    :"#{controller_path.split("/").first}_config"
  end
end

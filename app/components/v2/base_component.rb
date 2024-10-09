class V2::BaseComponent < ViewComponent::Base
  include ApplicationHelper
  include LinkHelper
  include AssetsHelper

  delegate :billing?,
    :billing_link,
    :current_user,
    :current_organization,
    :default_app,
    :new_app,
    :default_timezones,
    :content_security_policy_nonce,
    :logout_path,
    :ci_cd_provider_logo,
    :vcs_provider_logo,
    :live_release_tab_configuration,
    :live_release_overall_status,
    :teams_supported?,
    to: :helpers
  delegate :team_colors, to: :current_organization

  def writer?
    helpers&.writer?
  end

  def before_render
    if defined? @authz
      @disabled = true if !writer? && @authz
    end
  end

  def disabled? = @disabled

  def html_opts(method, message, params: {})
    {method:, params:, data: {turbo_method: method, turbo_confirm: message}}
  end
end

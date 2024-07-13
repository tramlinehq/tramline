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
    :logout_path, to: :helpers
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
end

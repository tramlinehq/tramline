class V2::BaseComponent < ViewComponent::Base
  include ApplicationHelper
  include LinkHelper
  include AssetsHelper

  delegate :billing?, :current_user, :current_organization, :default_app, :new_app, :default_timezones, to: :helpers

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

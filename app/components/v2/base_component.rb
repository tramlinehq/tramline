# frozen_string_literal: true

class V2::BaseComponent < ViewComponent::Base
  include ApplicationHelper
  include LinkHelper
  include AssetsHelper

  delegate :billing?, :current_user, :current_organization, :default_app, to: :helpers
end

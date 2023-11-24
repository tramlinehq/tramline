# frozen_string_literal: true

class V2::BaseComponent < ViewComponent::Base
  include ApplicationHelper
  include LinkHelper
  include AssetsHelper

  def billing? = helpers.billing?

  def current_user = helpers.current_user

  def current_organization = helpers.current_organization

  def default_app = helpers.default_app
end

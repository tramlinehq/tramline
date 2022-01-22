class Admin::SettingsController < ApplicationController
  before_action :admin?

  def index
  end

  private

  def admin?
    current_user.admin?
  end
end

class ApiController < ActionController::Base
  before_action :authenticate
  skip_before_action :verify_authenticity_token

  def current_user
    nil
  end
end

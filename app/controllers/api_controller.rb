class ApiController < ActionController::Base
  before_action :authorized_organization?
  before_action :authenticate
  skip_before_action :verify_authenticity_token

  rescue_from ActionController::ParameterMissing do
    head :bad_request
  end

  rescue_from ActiveRecord::RecordNotFound, ActiveRecord::SoleRecordExceeded do
    head :not_found
  end

  def authorized_organization?
    head(:unauthorized) if authorized_organization.blank?
  end

  def authenticate
    authenticate_or_request_with_http_token do |token, _options|
      ActiveSupport::SecurityUtils.secure_compare(token, authorized_organization.api_key)
    end
  end

  def authorized_organization
    @organization ||= Accounts::Organization.where(id: request.headers["HTTP_X_TRAMLINE_ACCOUNT_ID"]).first
  end
end

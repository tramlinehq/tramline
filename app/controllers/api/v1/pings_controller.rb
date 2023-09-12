class Api::V1::PingsController < ApiController
  skip_before_action :authenticate, only: [:show]

  rescue_from ActionController::ParameterMissing do
    head :bad_request
  end

  rescue_from ActiveRecord::RecordNotFound do
    head :not_found
  end

  def show
    render json: { status: "ok" }, status: :ok
  end
end

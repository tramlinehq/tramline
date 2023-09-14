class Api::V1::PingsController < ApiController
  skip_before_action :authorized_organization?
  skip_before_action :authenticate

  def show
    render json: {status: "ok"}, status: :ok
  end
end

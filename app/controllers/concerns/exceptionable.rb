module Exceptionable
  extend ActiveSupport::Concern

  included do
    rescue_from StandardError, with: :internal_server_error
    rescue_from ActiveRecord::RecordNotFound, ActionController::RoutingError, with: :not_found
    rescue_from ActionController::InvalidAuthenticityToken, with: :unprocessable_entity
    rescue_from ActionController::ParameterMissing, with: :bad_request
  end

  private

  def forbidden(e)
    message = t("errors.messages.not_authorized_policy", query: e.query, model: e.record.class)
    exception = StandardError.new(message)
    exception.set_backtrace(e.backtrace)

    respond_with_error(403, exception)
  end

  def not_found(e)
    respond_with_error(404, e)
  end

  def unprocessable_entity(e)
    respond_with_error(422, e)
  end

  def bad_request(e)
    respond_with_error(400, e)
  end

  def internal_server_error(e)
    Rails.logger.error e
    respond_with_error(500, e)
  end

  def respond_with_error(code, exception)
    Sentry.capture_exception(exception) if code >= 500

    respond_to do |format|
      @code = code
      @exception = exception
      @title = t("errors.messages.http_code.#{@code}.title")
      @content = t("errors.messages.http_code.#{@code}.content")
      @message = exception.message if code < 500

      format.any { render "errors/show", layout: "errors", status: code, formats: [:html] }
      format.json { render json: {code:, error: Rack::Utils::HTTP_STATUS_CODES[code]}, status: code }
    end
  end
end

class HealthController < Rails::HealthController
  before_action :log_health_check

  private

  def log_health_check
    Rails.logger.info "Health check requested at #{Time.current}"
    Rails.logger.info "Request path: #{request.path}"
  end
end

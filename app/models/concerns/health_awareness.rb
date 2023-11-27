module HealthAwareness
  extend ActiveSupport::Concern

  included do
    enum health_status: {healthy: "healthy", unhealthy: "unhealthy"}
  end
end

class TracerJob < ApplicationJob
  queue_as :default

  def perform(submitted_at)
    HTTP.get(ENV["WORKER_HEARTBEAT_URL"]) if ENV["WORKER_HEARTBEAT_URL"]
    Rails.logger.info("Tracer job completed successfully, was submitted at #{submitted_at}")
  end
end

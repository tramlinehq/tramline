class TracerJob < ApplicationJob
  queue_as :default

  def perform(submitted_at)
    # Bounded timeout: without it a stalled ping hangs the worker thread (this job
    # was seen stuck for minutes on a no-timeout HTTP.get).
    HTTP.timeout(connect: 5, read: 10).get(ENV["WORKER_HEARTBEAT_URL"]) if ENV["WORKER_HEARTBEAT_URL"]
    Rails.logger.info("Tracer job completed successfully, was submitted at #{submitted_at}")
  end
end

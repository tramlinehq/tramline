namespace :health do
  desc "Submit a job to check if workers are running"
  task worker_heartbeat: [:environment] do
    TracerJob.perform_later(Time.current.iso8601)
    puts "Submitted the tracer job!"
  end

  desc "Ping services that we depend on to check if they are running"
  task services_heartbeat: [:environment] do
    abort "No external services heartbeat URL set" unless ENV["EXT_SERVICES_HEARTBEAT_URL"]
    HTTP.get(ENV["EXT_SERVICES_HEARTBEAT_URL"]) if HTTP.get("#{ENV["APPLELINK_URL"]}/ping").status.success?
    puts "External services heartbeat passed!"
  rescue StandardError
    abort "External services heartbeat failed!"
  end
end

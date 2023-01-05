namespace :health do
  desc "Submit a job to check if workers are running"
  task heartbeat: [:environment] do
    TracerJob.perform_later(Time.current.iso8601)
    puts "Submitted the tracer job!"
  end
end

namespace :keep_alive_integration do
  desc "Start token keepalive jobs for existing GitLab integrations"
  task gitlab: :environment do
    puts "Scheduling keepalive jobs for GitLab integrations..."
    count = 0
    skipped = 0

    # Get all currently scheduled GitLab keepalive jobs
    scheduled_jobs = Sidekiq::ScheduledSet.new
    existing_job_args = scheduled_jobs
      .select { |job| job.klass == "KeepAliveIntegrations::GitlabJob" }
      .map(&:args)
      .flatten

    GitlabIntegration
      .joins(:integration)
      .where(integrations: {status: %w[connected needs_reauth]})
      .find_each do |gitlab_integration|
      # Skip if job already scheduled for this integration
      if existing_job_args.include?(gitlab_integration.id)
        skipped += 1
        next
      end

      # Schedule with a random delay to spread out the load
      delay = rand(0..6.hours.to_i)
      KeepAliveIntegrations::GitlabJob.perform_in(delay.seconds, gitlab_integration.id)

      count += 1
    end

    puts "Started keepalive jobs for #{count} GitLab integrations."
    puts "Skipped #{skipped} integrations (jobs already scheduled)." if skipped > 0
    puts "No GitLab integrations found." if count == 0 && skipped == 0
  end
end

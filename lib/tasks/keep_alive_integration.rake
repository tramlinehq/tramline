namespace :keep_alive_integration do
  schedule_keep_alive_jobs = lambda do |provider_name, providable_class, job_class|
    puts "Scheduling keepalive jobs for #{provider_name} integrations..."
    count = 0
    skipped = 0

    already_scheduled_ids = Sidekiq::ScheduledSet.new
      .select { |job| job.klass == job_class.name }
      .flat_map(&:args)

    providable_class
      .joins(:integration)
      .where(integrations: {status: %w[connected needs_reauth]})
      .find_each do |providable|
      if already_scheduled_ids.include?(providable.id)
        skipped += 1
        next
      end

      job_class.perform_in(rand(0..6.hours.to_i).seconds, providable.id)
      count += 1
    end

    puts "Started keepalive jobs for #{count} #{provider_name} integrations."
    puts "Skipped #{skipped} integrations (jobs already scheduled)." if skipped > 0
    puts "No #{provider_name} integrations found." if count == 0 && skipped == 0
  end

  desc "Start token keepalive jobs for existing GitLab integrations"
  task gitlab: :environment do
    schedule_keep_alive_jobs.call("GitLab", GitlabIntegration, KeepAliveIntegrations::GitlabJob)
  end

  desc "Start token keepalive jobs for existing Bitbucket integrations"
  task bitbucket: :environment do
    schedule_keep_alive_jobs.call("Bitbucket", BitbucketIntegration, KeepAliveIntegrations::BitbucketJob)
  end
end

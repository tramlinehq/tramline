namespace :metrics do
  desc "Superficial details on users and basic usage patterns"
  task :uptick, %i[hours webhook_url] => :environment do |_, args|
    UsageMetricsJob.new.perform(args[:hours].to_i, args[:webhook_url])
  end

  desc "Backfill user and org data in analytics db"
  task backfill_users: [:environment] do
    Accounts::User.find_each do |user|
      SiteAnalytics.identify(user)
      user.organizations.each do |org|
        SiteAnalytics.group(user, org)
      end
    end
  end
end

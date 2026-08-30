class UsageMetricsJob < ApplicationJob
  # Superficial usage digest (new orgs/apps/releases in the last `hours`) posted
  # to a Slack webhook. Was the site-usage-metrics Render cron
  # (rake metrics:uptick). The webhook URL is a secret, so it comes from the
  # environment rather than a committed schedule arg.
  def perform(hours = 24, webhook_url = ENV["USAGE_METRICS_WEBHOOK_URL"])
    ago = hours.to_i
    started_at = Time.current
    data = {}

    new_organizations = Accounts::Organization.where(created_at: ago.hours.ago..Time.current).includes(:users)
    new_apps = App.where(created_at: ago.hours.ago..Time.current).includes(:integrations, trains: [:releases])
    new_releases = Release.where(created_at: ago.hours.ago..Time.current)
      .includes(:all_commits, :release_platform_runs, train: [:release_platforms, {app: :organization}])

    data[:accounts] =
      new_organizations.map do |org|
        <<~DEETS
          Organization – #{org.name}
          Users – #{org.users.size}
        DEETS
      end

    data[:apps] =
      new_apps.map do |app|
        integrations = app.integrations
        trains = app.trains
        releases = trains.flat_map(&:releases)
        <<~DEETS
          App – #{app.bundle_identifier}
          Organization – #{app.organization.name}
          #{integrations.map { |i| "#{i.category.titleize} – #{i.providable.display}" }.join("\n")}
          Store Integration? – #{integrations.any?(&:store?)}
          Trains – #{trains.size}
          Releases – #{releases.size}
        DEETS
      end

    data[:releases] =
      new_releases.map do |release|
        train = release.train
        <<~DEETS
          App – #{release.app.bundle_identifier}
          Organization – #{release.app.organization.name}
          Train – #{train.name}
          Platforms – #{train.release_platforms.size}
          Platform Runs – #{release.release_platform_runs.size}
          Status – #{release.status}
          Commits – #{release.all_commits.size}
        DEETS
      end

    print_buf = +""
    data.each do |k, values|
      next if values.blank?
      print_buf << "New *#{k.to_s.titleize}*\n\n```\n"
      values.each { |v| print_buf << "#{v}\n" }
      print_buf.chop!
      print_buf << "```\n"
    end
    print_buf.chop!
    print_buf << "No new data" if print_buf.blank?
    print_buf.prepend "Run at #{started_at.strftime("%H:%M%Z – %d.%m.%Y")} | Data from the last #{ago} hours\n\n"

    logger.info(print_buf)
    HTTP.post(webhook_url, form: {payload: {text: print_buf}.to_json}) if webhook_url.present?
  end
end

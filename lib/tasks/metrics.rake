namespace :metrics do
  desc "Superficial details on users and basic usage patterns"
  task :uptick, %i[hours webhook_url] => :environment do |_, args|
    # collect data
    data = {}
    started_at = Time.current
    ago = args[:hours].to_i
    new_organizations = Accounts::Organization.where(created_at: ago.hours.ago..Time.current).includes(:users)
    new_apps = App.where(created_at: ago.hours.ago..Time.current).includes(:integrations, trains: [:runs])
    new_releases = Releases::Train::Run.where(created_at: ago.hours.ago..Time.current).includes(train: [steps: [:deployments]])

    # format data
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
        releases = trains.flat_map(&:runs)
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
          Steps – #{train.steps.size}
          Deployments – #{train.deployments.size}
          Status – #{release.status}
          Commits – #{release.commits.size}
        DEETS
      end

    # prepare data
    print_buf = ""
    data.each do |k, values|
      next if values.blank?
      key = k.to_s.titleize
      print_buf << "New *#{key}*"
      print_buf << "\n\n"
      print_buf << "```\n"
      values.each do |v|
        print_buf << v
        print_buf << "\n"
      end
      print_buf.chop!
      print_buf << "```\n"
    end
    print_buf.chop!
    print_buf << "No new data" if print_buf.blank?
    print_buf.prepend "Run at #{started_at.strftime("%H:%M%Z – %d.%m.%Y")} | Data from the last #{ago} hours\n\n"

    # send to stdout
    puts print_buf

    # send to slack
    payload = {text: print_buf}.to_json
    cmd = "curl -X POST --data-urlencode 'payload=#{payload}' #{args[:webhook_url]}"
    system(cmd)
  end
end

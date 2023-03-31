namespace :metrics do
  desc "Superficial details on users and basic usage patterns"
  task :uptick, %i[hours webhook_url] => :environment do |_, args|
    # collect data
    data = {}
    started_at = Time.current
    new_organizations = Accounts::Organization.where(created_at: args[:hours].to_i.hours.ago..Time.current)
    new_apps = App.where(created_at: args[:hours].to_i.hours.ago..Time.current).includes(:integrations, trains: [:runs])
    new_releases = Releases::Train::Run.where(created_at: args[:hours].to_i.hours.ago..Time.current).includes(train: [steps: [:deployments]])

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

    # print data
    print_buf = ""
    print_buf << "Run at #{started_at.strftime("%H:%M – %d.%m.%Y")}\n\n"
    data.each do |k, values|
      next if values.blank?
      key = k.to_s.titleize
      print_buf << "New *#{key}* in the last #{args[:hours]} hours"
      print_buf << "\n\n"
      print_buf << "```\n"
      values.each do |v|
        print_buf << v
        print_buf << "\n"
      end
      print_buf.chop!
      print_buf << "```\n"
    end
    puts print_buf.chop! if print_buf.present?

    # send to slack
    payload = {text: print_buf}.to_json
    cmd = "curl -X POST --data-urlencode 'payload=#{payload}' #{args[:webhook_url]}"
    system(cmd)
  end
end

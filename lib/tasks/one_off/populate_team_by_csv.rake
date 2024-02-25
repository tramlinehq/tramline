namespace :one_off do
  desc "Backfill author logins for commits in a release"
  task :populate_team, %i[organization_slug csv_file] => [:destructive, :environment] do |_, args|
    csv_file = args[:csv_file].to_s
    org_slug = args[:organization_slug].to_s
    org = Accounts::Organization.find_by!(slug: org_slug)

    File.foreach(csv_file).with_index do |line, line_num|
      puts "Processing line #{line_num}"
      user_email, github_login, team_name = line.split(",")
      team = org.teams.find_or_create_by!(name: team_name)
      user = org.users.find_by(email: user_email)
      if user.blank?
        puts "Missing user #{user_email}"
        next
      end

      membership = user.memberships.find_by!(organization: org)
      user.transaction do
        membership.update!(team:)
        user.update!(github_login:)
      end
    end
  end
end

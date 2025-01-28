require "csv"

namespace :membership do
  desc "Create an external viewer for a demo organization"
  task :create_external_viewer, %i[org_slug email_suffix password] => [:destructive, :environment] do |_, args|
    org_slug = args[:org_slug].to_s
    email_suffix = args[:email_suffix].to_s
    password = args[:password].to_s
    abort "No email suffix provided" if email_suffix.blank?
    abort "No password provided" if password.blank?

    organization = Accounts::Organization.find_by slug: org_slug
    abort "Org not found!" unless organization

    email = "external.viewer+#{email_suffix}@tramline.app"
    name = "Demo for #{email_suffix}"
    user = nil

    ActiveRecord::Base.transaction do
      email_authentication = Accounts::EmailAuthentication.find_or_initialize_by(email:)

      if email_authentication.persisted?
        abort "Email already exists!"
      else
        user = Accounts::User.find_or_create_by!(full_name: name, unique_authn_id: email)
        email_authentication.skip_confirmation_notification!
        email_authentication.update!(password:, confirmed_at: Time.current, user:)
        email_authentication.reload
      end

      Accounts::Membership.find_or_create_by!(
        user:,
        organization:,
        role: Accounts::Membership.roles[:viewer]
      )

      puts "Added the external viewer user with following credentials:"
      puts "Email: #{email}"
      puts "Password: #{password}"
    end

    SiteAnalytics.identify_and_group(user, organization)
  end

  desc "Bulk invite members of an organization"
  task :bulk_invite, %i[org_slug role filename sender_email] => [:destructive, :environment] do |_, args|
    org_slug = args[:org_slug].to_s
    org = Accounts::Organization.find_by slug: org_slug
    abort "Org not found!" unless org

    role = args[:role].to_s
    abort "Invalid role" unless Accounts::Invite.roles.value?(role)

    input_filename = args[:filename].to_s
    abort "Provide a valid filename" if input_filename.blank?
    abort "File does not exist" unless File.exist?(input_filename)

    sender_email = args[:sender_email].to_s
    abort "Sender email must be provided!" if sender_email.blank?
    sender = org.users.find_by(email: sender_email)
    abort "Sender not found!" if sender.blank?
    abort "Sender does not have permissions to invite" unless sender.writer_for?(org)

    csv_text = File.read(input_filename)
    emails = CSV.parse(csv_text, headers: false)&.flatten

    abort "No emails present in the file" if emails.empty?

    existing_emails = org.invites.where(email: emails).pluck(:email)

    new_emails = Set.new(emails) - Set.new(existing_emails)

    new_emails.each do |email|
      ActiveRecord::Base.transaction do
        invite = Accounts::Invite.new({organization_id: org.id, role:, email:})
        invite.sender = sender

        if invite.save
          if invite.recipient.present?
            InvitationMailer.existing_user(invite).deliver
          else
            InvitationMailer.new_user(invite).deliver
          end
        else
          puts "There was an error while saving the invite for #{email}!"
        end
      end
    rescue Postmark::ApiInputError
      puts "There was a delivery error while sending the invite for #{email}!"
    end

    puts "Invites successfully sent!"
  end
end

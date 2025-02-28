# rubocop:disable Rails/Output

module Seed
  class DevStarter
    def call
      puts "Seeding database..."

      ActiveRecord::Base.transaction do
        self.class.send(:create_admin_user)
        self.class.send(:create_owner_user)
        self.class.send(:create_developer_user)
      end

      puts "Completed seeding database"
    end

    def self.create_admin_user
      email_authentication = Accounts::EmailAuthentication.find_or_initialize_by(email: ADMIN_EMAIL)
      admin = true

      unless email_authentication.persisted?
        user = Accounts::User.find_or_create_by!(full_name: ADMIN_FULL_NAME, preferred_name: ADMIN_PREFERRED_NAME, admin:, unique_authn_id: ADMIN_EMAIL)
        email_authentication.update!(password: ADMIN_PASSWORD, confirmed_at: DateTime.now, user:)
      end

      puts "Added/updated admin user."
    end

    def self.create_owner_user
      email_authentication = Accounts::EmailAuthentication.find_or_initialize_by(email: OWNER_EMAIL)

      if email_authentication.persisted?
        user = email_authentication.user
      else
        user = Accounts::User.find_or_create_by!(full_name: OWNER_FULL_NAME, preferred_name: OWNER_PREFERRED_NAME, unique_authn_id: OWNER_EMAIL)
        email_authentication.update!(password: OWNER_PASSWORD, confirmed_at: DateTime.now, user:)
        email_authentication.reload
      end

      organization = Accounts::Organization.find_or_create_by!(
        name: "Tramline Test 1 (Owner)",
        status: Accounts::Organization.statuses[:active],
        created_by: email_authentication.email
      )

      Accounts::Membership.find_or_create_by!(
        user:,
        organization:,
        role: Accounts::Membership.roles[:owner]
      )

      puts "Added/updated owner user."
    end

    def self.create_developer_user
      email_authentication = Accounts::EmailAuthentication.find_or_initialize_by(email: DEVELOPER_EMAIL)

      if email_authentication.persisted?
        user = email_authentication.user
      else
        user = Accounts::User.find_or_create_by!(full_name: DEVELOPER_FULL_NAME, preferred_name: DEVELOPER_PREFERRED_NAME, unique_authn_id: DEVELOPER_EMAIL)
        email_authentication.update!(password: DEVELOPER_PASSWORD, confirmed_at: DateTime.now, user:)
        email_authentication.reload
      end

      organization = Accounts::Organization.find_or_create_by!(
        name: "Tramline Test 1 (Developer)",
        status: Accounts::Organization.statuses[:active],
        created_by: email_authentication.email
      )

      Accounts::Membership.find_or_create_by!(
        user:,
        organization:,
        role: Accounts::Membership.roles[:developer]
      )

      puts "Added/updated developer user."
    end

    private_class_method :create_admin_user
    private_class_method :create_owner_user
    private_class_method :create_developer_user
  end
end

# rubocop:enable Rails/Output

puts "Seeding database..."

# Admin user
# ----------
ADMIN_FULL_NAME = "Admin User"
ADMIN_PREFERRED_NAME = "Admin"
ADMIN_EMAIL = "admin@tramline.app"
ADMIN_PASSWORD = "why aroma enclose startup"

admin_user = lambda do
  Accounts::User.create!(
    full_name: ADMIN_FULL_NAME,
    preferred_name: ADMIN_PREFERRED_NAME,
    email: ADMIN_EMAIL,
    password: ADMIN_PASSWORD,
    admin: true,
    confirmed_at: DateTime.now
  )

  puts "Added admin user."
end

# Owner user
# --------------
OWNER_FULL_NAME = "Owner User"
OWNER_PREFERRED_NAME = "Owner"
OWNER_EMAIL = "owner@tramline.app"
OWNER_PASSWORD = "why aroma enclose startup"

owner_user = lambda do
  user = Accounts::User.create!(
    full_name: OWNER_FULL_NAME,
    preferred_name: OWNER_PREFERRED_NAME,
    email: OWNER_EMAIL,
    password: OWNER_PASSWORD,
    confirmed_at: DateTime.now
  )

  organization = Accounts::Organization.create!(
    name: "Tramline Test 1",
    status: Accounts::Organization.statuses[:active],
    created_by: user.email
  )

  Accounts::Membership.create!(
    user:,
    organization:,
    role: Accounts::Membership.roles[:owner]
  )

  puts "Added owner user."
end

# Developer user
# --------------
DEVELOPER_FULL_NAME = "Developer User"
DEVELOPER_PREFERRED_NAME = "Developer"
DEVELOPER_EMAIL = "developer@tramline.app"
DEVELOPER_PASSWORD = "why aroma enclose startup"

developer_user = lambda do
  user = Accounts::User.create!(
    full_name: DEVELOPER_FULL_NAME,
    preferred_name: DEVELOPER_PREFERRED_NAME,
    email: DEVELOPER_EMAIL,
    password: DEVELOPER_PASSWORD,
    confirmed_at: DateTime.now
  )

  organization = Accounts::Organization.create!(
    name: "Tramline Test (developer)",
    status: Accounts::Organization.statuses[:active],
    created_by: user.email
  )

  Accounts::Membership.create!(
    user:,
    organization:,
    role: Accounts::Membership.roles[:developer]
  )

  puts "Added developer user."
end

ActiveRecord::Base.transaction do
  admin_user.call
  owner_user.call
  developer_user.call
end

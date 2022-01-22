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
    admin: true
  )

  puts "Added admin user."
end

# Executive user
# --------------
EXECUTIVE_FULL_NAME = "Executive User"
EXECUTIVE_PREFERRED_NAME = "Executive"
EXECUTIVE_EMAIL = "executive@tramline.app"
EXECUTIVE_PASSWORD = "why aroma enclose startup"

executive_user = lambda do
  user = Accounts::User.create!(
    full_name: EXECUTIVE_FULL_NAME,
    preferred_name: EXECUTIVE_PREFERRED_NAME,
    email: EXECUTIVE_EMAIL,
    password: EXECUTIVE_PASSWORD
  )

  organization = Accounts::Organization.create!(
    name: "Tramline Test 1",
    status: Accounts::Organization.statuses[:active],
    created_by: user.email
  )

  Accounts::Membership.create!(
    user:,
    organization:,
    role: Accounts::Membership.roles[:executive]
  )

  puts "Added executive user."
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
    password: DEVELOPER_PASSWORD
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
  executive_user.call
  developer_user.call
end

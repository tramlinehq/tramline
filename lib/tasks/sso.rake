namespace :sso do
  desc "Enable SAML SSO for the organization and its users"
  task :enable_saml, %i[org_slug tenant_id tenant_name domains configuration_link] => [:destructive, :environment] do |_, args|
    org_slug = args[:org_slug].to_s
    organization = Accounts::Organization.find_by(slug: org_slug)
    abort "Organization not found!" unless organization
    abort "Organization already has SSO enabled!" if organization.sso?

    tenant_id = args[:tenant_id].to_s
    tenant_name = args[:tenant_name].to_s
    domains = args[:domains].to_s.split(",")
    configuration_link = args[:configuration_link].to_s

    abort "Tenant ID is required!" if tenant_id.blank?
    abort "Tenant Name is required!" if tenant_name.blank?
    abort "Domains are required!" if domains.blank?
    abort "Configuration Link is required!" if configuration_link.blank?

    puts "Enabling SSO for #{organization.name}..."
    puts "Tenant ID: #{tenant_id}"
    puts "Tenant Name: #{tenant_name}"
    puts "Domains: #{domains}"
    puts "Configuration Link: #{configuration_link}"

    ActiveRecord::Base.transaction do
      organization.sso = true
      organization.sso_tenant_id = tenant_id
      organization.sso_tenant_name = tenant_name
      organization.sso_domains = domains
      organization.sso_configuration_link = configuration_link
      organization.sso_protocol = "saml"

      organization.users.each do |user|
        sso_auth = Accounts::SsoAuthentication.new(email: user.email)
        user.user_authentications.create!(authenticatable: sso_auth)
        user.save!
      end

      organization.save!
    end

    puts "SSO successfully enabled!"
  end
end

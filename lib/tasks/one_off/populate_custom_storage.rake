namespace :one_off do
  desc "Populates custom storage for a tenant"
  task :populate_custom_storage, [:organization_id, :bucket, :bucket_region, :service_key] => :environment do |_, args|
    organization = Accounts::Organization.find(args[:organization_id])
    custom_storage = Accounts::CustomStorage.find_or_initialize_by(organization: organization)
    custom_storage.update!(
      bucket: args[:bucket],
      bucket_region: args[:bucket_region],
      service: args[:service_key]
    )

    puts "Custom storage populated for organization #{organization.name}"
  end
end

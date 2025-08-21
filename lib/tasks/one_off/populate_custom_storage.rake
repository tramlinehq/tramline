namespace :one_off do
  desc "Populates custom storage for a tenant"
  task :populate_custom_storage, [:organization_id, :bucket, :project_id] => :environment do |_, args|
    organization = Accounts::Organization.find(args[:organization_id])
    credentials_json = ENV['CUSTOM_STORAGE_CREDENTIALS']
    raise "No credentials provided via CUSTOM_STORAGE_CREDENTIALS env var" if credentials_json.blank?
    credentials = JSON.parse(credentials_json)

    custom_storage = Accounts::CustomStorage.find_or_initialize_by(organization: organization)
    custom_storage.update!(
      bucket: args[:bucket],
      project_id: args[:project_id],
      credentials: credentials
    )

    puts "Custom storage populated for organization #{organization.name}"
  end
end

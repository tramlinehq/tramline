class AddCustomStorageServiceKeyToOrgs < ActiveRecord::Migration[7.0]
  def change
    add_column :organizations, :custom_storage_service_key, :string
  end
end

class AddApiKeyToOrganization < ActiveRecord::Migration[7.0]
  def change
    add_column :organizations, :api_key, :string
  end
end

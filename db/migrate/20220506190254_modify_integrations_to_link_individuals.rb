class ModifyIntegrationsToLinkIndividuals < ActiveRecord::Migration[7.0]
  def change
    remove_column :integrations, :active_code_repo, :json
    remove_column :integrations, :notification_channel, :json
    remove_column :integrations, :working_branch, :string
    remove_column :integrations, :installation_id, :string
    remove_column :integrations, :oauth_access_token, :string
    remove_column :integrations, :original_oauth_access_token, :string
    remove_column :integrations, :provider, :string

    add_column :integrations, :providable_id, :uuid
    add_column :integrations, :providable_type, :string
    add_index :integrations, [:providable_type, :providable_id], unique: true
  end
end

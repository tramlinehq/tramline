class AddIntegrationsForAppVariants < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_column :integrations, :integrable_id, :uuid
    add_column :integrations, :integrable_type, :string
  end
end

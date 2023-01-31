class AddExternalIdToApp < ActiveRecord::Migration[7.0]
  def change
    add_column :apps, :external_id, :string
  end
end

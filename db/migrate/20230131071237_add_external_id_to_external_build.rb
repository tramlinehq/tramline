class AddExternalIdToExternalBuild < ActiveRecord::Migration[7.0]
  def change
    add_column :external_builds, :external_id, :string
  end
end

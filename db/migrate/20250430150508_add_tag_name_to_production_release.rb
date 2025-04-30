class AddTagNameToProductionRelease < ActiveRecord::Migration[7.2]
  def change
    add_column :production_releases, :tag_name, :string, null: true
  end
end

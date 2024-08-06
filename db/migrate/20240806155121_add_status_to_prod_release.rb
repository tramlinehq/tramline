class AddStatusToProdRelease < ActiveRecord::Migration[7.0]
  def change
    add_column :production_releases, :status, :string, null: false, default: "created"
  end
end

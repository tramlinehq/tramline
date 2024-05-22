class AddUniqueIndexToSlugOnReleases < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_index :releases, :slug, unique: true, algorithm: :concurrently
  end
end

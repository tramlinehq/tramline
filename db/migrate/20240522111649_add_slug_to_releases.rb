class AddSlugToReleases < ActiveRecord::Migration[7.0]
  def change
    add_column :releases, :slug, :string
  end
end

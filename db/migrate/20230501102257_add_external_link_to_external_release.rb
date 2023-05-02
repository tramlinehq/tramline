class AddExternalLinkToExternalRelease < ActiveRecord::Migration[7.0]
  def change
    add_column :external_releases, :external_link, :string
  end
end

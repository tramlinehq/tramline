class AddFieldsToReleaseMetadata < ActiveRecord::Migration[7.0]
  def change
    add_column :release_metadata, :description, :text
    add_column :release_metadata, :keywords, :string, array: true, default: []
    add_column :release_metadata, :default_locale, :boolean, default: false
  end
end

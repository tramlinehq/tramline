class AddAuthorMetadataToPassports < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      rename_column :passports, :user_id, :author_id
      add_column :passports, :author_metadata, :jsonb
      add_column :passports, :automatic, :boolean, default: true
      add_index :passports, :author_id
    end
  end
end

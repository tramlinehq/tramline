class AddDraftKeywordsAndDescriptionToReleaseMetadata < ActiveRecord::Migration[7.2]
  def change
    add_column :release_metadata, :draft_keywords, :string, array: true, default: []
    add_column :release_metadata, :draft_description, :text
  end
end

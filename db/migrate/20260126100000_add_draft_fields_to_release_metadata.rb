class AddDraftFieldsToReleaseMetadata < ActiveRecord::Migration[7.2]
  def change
    add_column :release_metadata, :draft_release_notes, :text
    add_column :release_metadata, :draft_promo_text, :text
  end
end

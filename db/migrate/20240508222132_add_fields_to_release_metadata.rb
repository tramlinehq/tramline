class AddFieldsToReleaseMetadata < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      change_table :release_metadata, bulk: true do |t|
        t.text :description, null: true
        t.string :keywords, array: true, default: [], null: true
        t.boolean :default_locale, default: false
      end
    end
  end
end

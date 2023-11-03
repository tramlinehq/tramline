class AddReleaseTypeToRelease < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      add_column :releases, :release_type, :string
      Release.update_all(release_type: "release")
      change_column_null :releases, :release_type, false
      add_column :releases, :hotfixed_from, :uuid, null: true
    end
  end
end

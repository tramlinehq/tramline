class RenameExternalBuildToExternalRelease < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      rename_table :external_builds, :external_releases
    end
  end
end

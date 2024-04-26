class AddReleasePilotToRelease < ActiveRecord::Migration[7.0]
  def change
    add_column :releases, :release_pilot_id, :uuid, null: true
  end
end

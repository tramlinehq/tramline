class AddReleaseNotesCheckInDeployments < ActiveRecord::Migration[7.0]
  def change
    add_column :deployments, :notes, :string, default: "no_notes", null: false
  end
end

class AddReleaseNotesCheckInDeployments < ActiveRecord::Migration[7.0]
  def change
    add_column :deployments, :send_release_notes, :boolean, default: false
  end
end

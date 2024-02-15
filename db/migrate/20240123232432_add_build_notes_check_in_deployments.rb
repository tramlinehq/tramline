class AddBuildNotesCheckInDeployments < ActiveRecord::Migration[7.0]
  def change
    add_column :deployments, :send_build_notes, :boolean
  end
end

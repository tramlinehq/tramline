class AddResubmissionModeToReleasePlatformRun < ActiveRecord::Migration[7.0]
  def change
    add_column :release_platform_runs, :in_store_resubmission, :boolean, default: false
  end
end

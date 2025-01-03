class AddAutoApplyPatchChangesFlagToTrain < ActiveRecord::Migration[7.2]
  def change
    add_column :trains, :auto_apply_patch_changes, :boolean, default: true
  end
end

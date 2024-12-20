class AddCopyApprovalsToTrain < ActiveRecord::Migration[7.2]
  def change
    add_column :trains, :copy_approvals, :boolean, default: false
  end
end

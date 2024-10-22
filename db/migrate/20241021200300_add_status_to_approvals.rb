class AddStatusToApprovals < ActiveRecord::Migration[7.2]
  def change
    add_column :approval_items, :status, :string, default: "not_started"
  end
end

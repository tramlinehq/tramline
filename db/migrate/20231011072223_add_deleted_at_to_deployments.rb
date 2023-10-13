class AddDeletedAtToDeployments < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      add_column :deployments, :discarded_at, :datetime
      add_index :deployments, :discarded_at
    end
  end
end

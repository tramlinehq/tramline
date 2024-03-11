class AddDiscardedAtToIntegrations < ActiveRecord::Migration[7.0]
  def change
    add_column :integrations, :discarded_at, :datetime
  end
end

class RemoveBuildsFromStoreRollouts < ActiveRecord::Migration[7.0]
  def change
    safety_assured { remove_column :store_rollouts, :build_id, :jsonb }
  end
end

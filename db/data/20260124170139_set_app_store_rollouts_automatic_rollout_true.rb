# frozen_string_literal: true

class SetAppStoreRolloutsAutomaticRolloutTrue < ActiveRecord::Migration[7.2]
  def up
    AppStoreRollout.update_all(automatic_rollout: true)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

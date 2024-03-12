class ChangeDiscardedStepCiCdChannelUniqueIndex < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    remove_index :steps, name: "index_steps_on_ci_cd_channel_and_release_platform_id"
    add_index :steps, [:release_platform_id, :ci_cd_channel], unique: true, where: "discarded_at IS NULL", name: "index_kept_steps_on_release_platform_id_and_ci_cd_channel", algorithm: :concurrently
  end
end

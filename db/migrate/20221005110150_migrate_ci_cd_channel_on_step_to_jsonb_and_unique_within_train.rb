class MigrateCiCdChannelOnStepToJsonbAndUniqueWithinTrain < ActiveRecord::Migration[7.0]
  def change
    change_column :train_steps, :ci_cd_channel, :jsonb
    add_index :train_steps, [:ci_cd_channel, :train_id], unique: true
  end
end

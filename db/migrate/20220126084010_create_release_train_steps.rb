class CreateReleaseTrainSteps < ActiveRecord::Migration[7.0]
  def change
    create_table :release_train_steps, id: :uuid do |t|
      t.belongs_to :release_train, null: false, index: true, foreign_key: true, type: :uuid

      t.string :name, null: false
      t.string :description, null: false
      t.string :status, null: false
      t.integer :step_number, default: 0, null: false, limit: 2 # smallint

      t.string :build_artifact_channel, null: false
      t.string :ci_cd_channel, null: false

      t.timestamps
    end
  end
end

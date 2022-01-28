class CreateTrainSteps < ActiveRecord::Migration[7.0]
  def change
    create_table :train_steps, id: :uuid do |t|
      t.belongs_to :train, null: false, index: true, foreign_key: true, type: :uuid

      t.string :name, null: false
      t.string :description, null: false
      t.string :status, null: false
      t.integer :step_number, default: 0, null: false, limit: 2 # smallint
      t.interval :run_after_duration, null: false

      t.string :build_artifact_channel, null: false
      t.string :ci_cd_channel, null: false

      t.string :slug

      t.timestamps
    end

    add_index :train_steps, [:step_number], unique: true
  end
end

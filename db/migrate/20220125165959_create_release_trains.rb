class CreateReleaseTrains < ActiveRecord::Migration[7.0]
  def change
    create_table :release_trains, id: :uuid do |t|
      t.belongs_to :app, null: false, index: true, foreign_key: true, type: :uuid

      t.string :name, null: false
      t.string :description, null: false

      t.string :version_seeded_with, null: false
      t.string :version_current
      t.string :version_suffix, null: false

      t.timestamp :kickoff_at, null: false
      t.interval :repeat_duration, null: false

      t.string :working_branch, null: false
      t.integer :step_count, default: 0, null: false, limit: 2 # smallint

      t.timestamps
    end

    add_index :release_trains, [:version_suffix, :app_id], unique: true
  end
end

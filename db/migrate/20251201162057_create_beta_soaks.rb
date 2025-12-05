class CreateBetaSoaks < ActiveRecord::Migration[7.2]
  def change
    create_table :beta_soaks, id: :uuid do |t|
      t.references :release, null: false, foreign_key: true, type: :uuid
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.integer :period_hours, null: false

      t.timestamps
    end
  end
end

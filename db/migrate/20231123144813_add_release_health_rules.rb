class AddReleaseHealthRules < ActiveRecord::Migration[7.0]
  def change
    create_table :release_health_rules, id: :uuid do |t|
      t.belongs_to :train, null: false, index: true, foreign_key: true, type: :uuid

      t.string :metric, null: false, index: true
      t.string :comparator, null: false
      t.float :threshold_value, null: false
      t.boolean :is_halting, null: false, default: false

      t.timestamps
    end

    add_index :release_health_rules, [:train_id, :metric], unique: true
  end
end

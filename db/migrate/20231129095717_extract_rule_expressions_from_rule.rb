class ExtractRuleExpressionsFromRule < ActiveRecord::Migration[7.0]
  def change
    create_table :rule_expressions, id: :uuid do |t|
      t.belongs_to :release_health_rule, null: false, foreign_key: true, type: :uuid

      t.string :type, null: false
      t.string :metric, null: false, index: true
      t.string :comparator, null: false
      t.float :threshold_value, null: false

      t.timestamps
    end

    add_index :rule_expressions, [:release_health_rule_id, :metric], unique: true

    safety_assured do
      add_column :release_health_rules, :name, :string
      remove_column :release_health_rules, :metric, :string
      remove_column :release_health_rules, :comparator, :string
      remove_column :release_health_rules, :threshold_value, :float
    end
  end
end

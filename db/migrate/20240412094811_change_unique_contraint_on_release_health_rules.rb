class ChangeUniqueContraintOnReleaseHealthRules < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    remove_index :rule_expressions, [:release_health_rule_id, :metric], unique: true
    add_index :rule_expressions,
      [:release_health_rule_id, :metric],
      unique: true,
      where: "type = 'TriggerRuleExpression'",
      name: "unique_index_on_release_health_rule_id_and_metric_for_triggers",
      algorithm: :concurrently
  end
end

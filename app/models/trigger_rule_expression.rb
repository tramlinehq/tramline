# == Schema Information
#
# Table name: rule_expressions
#
#  id                     :uuid             not null, primary key
#  comparator             :string           not null
#  metric                 :string           not null, indexed, indexed => [release_health_rule_id]
#  threshold_value        :float            not null
#  type                   :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  release_health_rule_id :uuid             not null, indexed, indexed => [metric]
#
class TriggerRuleExpression < RuleExpression
  enum metric: {
    session_stability: "session_stability",
    user_stability: "user_stability",
    errors: "errors",
    new_errors: "new_errors"
  }
end

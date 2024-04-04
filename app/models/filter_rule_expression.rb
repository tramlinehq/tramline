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
class FilterRuleExpression < RuleExpression
  enum metric: ReleaseHealthMetric::METRIC_VALUES.slice(:adoption_rate, :staged_rollout).transform_values(&:to_s)
end

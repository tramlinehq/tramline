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
class RuleExpression < ApplicationRecord
  include Displayable
  belongs_to :release_health_rule

  enum comparator: {
    lt: "lt",
    lte: "lte",
    gt: "gt",
    gte: "gte",
    eq: "eq"
  }

  COMPARATORS = {
    lt: ->(value, threshold) { value < threshold },
    lte: ->(value, threshold) { value <= threshold },
    gt: ->(value, threshold) { value > threshold },
    gte: ->(value, threshold) { value >= threshold },
    eq: ->(value, threshold) { value == threshold }
  }

  validates :metric, uniqueness: {scope: :release_health_rule_id}

  def evaluate(value)
    comparator_proc = COMPARATORS[comparator.to_sym]
    raise ArgumentError, "Invalid comparator" unless comparator_proc

    comparator_proc.call(value, threshold_value)
  end

  COMPARATOR_DESCRIPTION = {
    lt: {healthy: "is above", unhealthy: "is below"},
    lte: {healthy: "is above", unhealthy: "is below"},
    gt: {healthy: "is below", unhealthy: "is above"},
    gte: {healthy: "is below", unhealthy: "is above"},
    eq: {healthy: "is not equal to", unhealthy: "is equal to"}
  }.with_indifferent_access

  def describe_comparator(health_status)
    COMPARATOR_DESCRIPTION[comparator][health_status]
  end
end

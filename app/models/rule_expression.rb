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

  enum :comparator, {
    lt: "lt",
    lte: "lte",
    gt: "gt",
    gte: "gte",
    eq: "eq"
  }

  COMPARATORS = {
    lt: {fn: ->(value, threshold) { value < threshold },
         description: {healthy: ">=", unhealthy: "<"}},
    lte: {fn: ->(value, threshold) { value <= threshold },
          description: {healthy: ">", unhealthy: "<="}},
    gt: {fn: ->(value, threshold) { value > threshold },
         description: {healthy: "<=", unhealthy: ">"}},
    gte: {fn: ->(value, threshold) { value >= threshold },
          description: {healthy: "<", unhealthy: ">="}},
    eq: {fn: ->(value, threshold) { value == threshold },
         description: {healthy: "!=", unhealthy: "=="}}
  }.with_indifferent_access

  def self.comparator_options
    COMPARATORS.map { |k, v| [v[:description][:unhealthy], k] }.to_h
  end

  def evaluate(value)
    comparator_proc = COMPARATORS[comparator.to_sym][:fn]
    raise ArgumentError, "Invalid comparator" unless comparator_proc

    comparator_proc.call(value, threshold_value)
  end

  def describe_comparator(health_status)
    COMPARATORS[comparator][:description][health_status]
  end

  def to_s(health_status = :unhealthy)
    "#{metric.titleize} #{describe_comparator(health_status)} #{threshold_value}"
  end
end

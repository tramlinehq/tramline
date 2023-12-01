# == Schema Information
#
# Table name: release_health_rules
#
#  id                  :uuid             not null, primary key
#  is_halting          :boolean          default(FALSE), not null
#  name                :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  release_platform_id :uuid             not null, indexed
#
class ReleaseHealthRule < ApplicationRecord
  belongs_to :release_platform
  has_many :trigger_rule_expressions, dependent: :destroy
  has_many :filter_rule_expressions, dependent: :destroy

  def healthy?(metric)
    return true if trigger_rule_expressions.blank?

    filters = filter_rule_expressions.map do |expr|
      value = metric.send(ReleaseHealthMetric::METRIC_VALUES[expr.metric])
      expr.evaluate(value) if value
    end

    return true unless filters.all?

    triggers = trigger_rule_expressions.map do |expr|
      value = metric.send(ReleaseHealthMetric::METRIC_VALUES[expr.metric])
      expr.evaluate(value) if value
    end.compact

    !triggers.any?
  end

  def description
    name + " rule with condition(s): " + trigger_rule_expressions.map(&:description).join(", ")
  end
end

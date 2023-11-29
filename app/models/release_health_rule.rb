# == Schema Information
#
# Table name: release_health_rules
#
#  id         :uuid             not null, primary key
#  is_halting :boolean          default(FALSE), not null
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  train_id   :uuid             not null, indexed
#
class ReleaseHealthRule < ApplicationRecord
  belongs_to :train
  has_many :trigger_rule_expressions, dependent: :destroy
  has_many :filter_rule_expressions, dependent: :destroy

  def healthy?(metric)
    return self.class.health_statuses[:healthy] if trigger_rule_expressions.blank?

    results = trigger_rule_expressions.map do |expr|
      value = metric.send(ReleaseHealthMetric::METRIC_VALUES[expr.metric])
      expr.evaluate(value) if value
    end.compact

    !results.any?
  end

  def description
    name + " rule with condition(s): " + trigger_rule_expressions.map(&:description).join(", ")
  end
end

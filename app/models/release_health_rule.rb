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
  alias_method :filters, :filter_rule_expressions
  alias_method :triggers, :trigger_rule_expressions

  scope :for_metric, ->(metric) { includes(:trigger_rule_expressions).where(trigger_rule_expressions: {metric:}) }

  def healthy?(metric)
    return true if triggers.blank?

    filters_passed = filters.all? do |expr|
      value = metric.evaluate(expr.metric)
      expr.evaluate(value) if value
    end

    return true unless filters_passed

    triggers.none? do |expr|
      value = metric.evaluate(expr.metric)
      expr.evaluate(value) if value
    end
  end
end

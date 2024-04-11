# == Schema Information
#
# Table name: release_health_rules
#
#  id                  :uuid             not null, primary key
#  discarded_at        :datetime         indexed
#  is_halting          :boolean          default(FALSE), not null
#  name                :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  release_platform_id :uuid             not null, indexed
#
class ReleaseHealthRule < ApplicationRecord
  has_paper_trail
  include Discard::Model

  belongs_to :release_platform
  has_many :trigger_rule_expressions, dependent: :destroy
  has_many :filter_rule_expressions, dependent: :destroy
  alias_method :filters, :filter_rule_expressions
  alias_method :triggers, :trigger_rule_expressions

  scope :for_metric, ->(metric) { includes(:trigger_rule_expressions).where(trigger_rule_expressions: {metric:}) }

  validates :trigger_rule_expressions, presence: true
  validate :unique_metrics
  accepts_nested_attributes_for :trigger_rule_expressions
  accepts_nested_attributes_for :filter_rule_expressions

  after_create_commit :check_release_health

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

  private

  def check_release_health
    release_platform.release_platform_runs.on_track.each(&:check_release_health)
  end

  def unique_metrics
    trigger_duplicates = triggers
      .group_by { |expr| expr.values_at(:metric) }
      .values
      .detect { |arr| arr.size > 1 }

    errors.add(:trigger_rule_expressions, :duplicate_metrics) if trigger_duplicates

    filter_duplicates = filters
      .group_by { |expr| expr.values_at(:metric) }
      .values
      .detect { |arr| arr.size > 1 }

    errors.add(:filter_rule_expressions, :duplicate_metrics) if filter_duplicates
  end
end

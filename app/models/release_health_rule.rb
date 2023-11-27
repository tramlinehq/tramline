# == Schema Information
#
# Table name: release_health_rules
#
#  id              :uuid             not null, primary key
#  comparator      :string           not null
#  is_halting      :boolean          default(FALSE), not null
#  metric          :string           not null, indexed, indexed => [train_id]
#  threshold_value :float            not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  train_id        :uuid             not null, indexed, indexed => [metric]
#
class ReleaseHealthRule < ApplicationRecord
  belongs_to :train

  enum metric: {
    session_stability: "session_stability",
    user_stability: "user_stability",
    errors: "errors",
    new_errors: "new_errors"
  }

  enum comparator: {
    lt: "lt",
    lte: "lte",
    gt: "gt",
    gte: "gte",
    eq: "eq"
  }

  enum health_status: {healthy: "healthy", unhealthy: "unhealthy"}

  COMPARATORS = {
    lt: ->(value, threshold) { value < threshold },
    lte: ->(value, threshold) { value <= threshold },
    gt: ->(value, threshold) { value > threshold },
    gte: ->(value, threshold) { value >= threshold },
    eq: ->(value, threshold) { value == threshold }
  }

  validates :metric, uniqueness: {scope: :train_id}

  def evaluate(value)
    comparator_proc = COMPARATORS[comparator.to_sym]
    raise ArgumentError, "Invalid comparator" unless comparator_proc

    return ReleaseHealthRule.health_statuses[:healthy] if comparator_proc.call(value, threshold_value)
    ReleaseHealthRule.health_statuses[:unhealthy]
  end
end

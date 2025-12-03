# == Schema Information
#
# Table name: beta_soaks
#
#  id           :uuid             not null, primary key
#  ended_at     :datetime
#  period_hours :integer          not null
#  started_at   :datetime         not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  release_id   :uuid             not null, indexed
#
class BetaSoak < ApplicationRecord
  include Passportable

  belongs_to :release

  STAMPABLE_REASONS = %w[
    beta_soak_started
    beta_soak_extended
    beta_soak_ended
  ]

  def expired?
    Time.current >= (started_at + period_hours.hours)
  end

  def end_time
    started_at + period_hours.hours
  end

  def time_remaining
    return 0 if expired? || ended_at.present?
    remaining = end_time - Time.current
    [remaining, 0].max
  end
end

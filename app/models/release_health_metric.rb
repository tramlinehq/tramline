# == Schema Information
#
# Table name: release_health_metrics
#
#  id                      :uuid             not null, primary key
#  daily_users             :bigint
#  daily_users_with_errors :bigint
#  errors                  :bigint
#  fetched_at              :datetime         not null, indexed
#  new_errors              :bigint
#  sessions                :bigint
#  sessions_in_last_day    :bigint
#  sessions_with_errors    :bigint
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  deployment_run_id       :uuid             not null, indexed
#
class ReleaseHealthMetric < ApplicationRecord
  def user_stability
    return if daily_users&.zero?
    ((1 - (daily_users_with_errors.to_f / daily_users.to_f)) * 100).ceil(2)
  end

  def session_stability
    return if sessions&.zero?
    ((1 - (sessions_with_errors.to_f / sessions.to_f)) * 100).ceil(2)
  end

  def adoption_rate
    return 0 if sessions.zero?
    (sessions_in_last_day.to_f / sessions.to_f).ceil(2)
  end
end

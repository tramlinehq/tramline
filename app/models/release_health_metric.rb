# == Schema Information
#
# Table name: release_health_metrics
#
#  id                         :uuid             not null, primary key
#  daily_users                :bigint
#  daily_users_with_errors    :bigint
#  errors_count               :bigint
#  fetched_at                 :datetime         not null, indexed
#  new_errors_count           :bigint
#  sessions                   :bigint
#  sessions_in_last_day       :bigint
#  sessions_with_errors       :bigint
#  total_sessions_in_last_day :bigint
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  deployment_run_id          :uuid             not null, indexed
#
class ReleaseHealthMetric < ApplicationRecord
  belongs_to :deployment_run
  has_one :release_health_event, dependent: :nullify

  delegate :train, to: :deployment_run

  after_create_commit :check_release_health

  METRIC_VALUES = {
    session_stability: :session_stability,
    user_stability: :user_stability,
    errors: :errors_count,
    new_errors: :new_errors_count
  }.with_indifferent_access

  def user_stability
    return if daily_users.blank? || daily_users.zero?
    ((1 - (daily_users_with_errors.to_f / daily_users.to_f)) * 100).ceil(3)
  end

  def session_stability
    return if sessions.blank? || sessions.zero?
    ((1 - (sessions_with_errors.to_f / sessions.to_f)) * 100).ceil(3)
  end

  def adoption_rate
    return 0 if total_sessions_in_last_day.blank? || total_sessions_in_last_day.zero?
    ((sessions_in_last_day.to_f / total_sessions_in_last_day.to_f) * 100).ceil(2)
  end

  def check_release_health
    return if train.release_health_rules.blank?
    train.release_health_rules.each do |rule|
      value = send(METRIC_VALUES[rule.metric])
      next unless value
      create_health_event(rule, value)
    end
  end

  def create_health_event(rule, value)
    last_event = deployment_run.release_health_events.where(release_health_rule: rule).last

    current_status = rule.evaluate(value)
    return if last_event.blank? && current_status == ReleaseHealthRule.health_statuses[:healthy]
    return if last_event.present? && last_event.health_status == current_status
    create_release_health_event(deployment_run:, release_health_rule: rule, health_status: current_status, event_timestamp: fetched_at)
  end
end

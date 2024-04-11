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
#  external_release_id        :string
#
class ReleaseHealthMetric < ApplicationRecord
  belongs_to :deployment_run
  has_many :release_health_events, dependent: :nullify

  delegate :release_health_rules, to: :deployment_run

  after_create_commit :check_release_health

  METRIC_VALUES = {
    session_stability: :session_stability,
    user_stability: :user_stability,
    errors_count: :errors_count,
    new_errors_count: :new_errors_count,
    adoption_rate: :adoption_rate,
    staged_rollout: :staged_rollout
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

  def staged_rollout
    deployment_run.rollout_percentage
  end

  def check_release_health
    return if release_health_rules.blank?
    release_health_rules.each do |rule|
      create_health_event(rule)
    end
  end

  def evaluate(metric_name)
    METRIC_VALUES[metric_name].present? ? public_send(METRIC_VALUES[metric_name]) : nil
  end

  def create_health_event(release_health_rule)
    last_event = deployment_run.release_health_events.where(release_health_rule:).last
    is_healthy = release_health_rule.healthy?(self)
    current_status = is_healthy ? ReleaseHealthEvent.health_statuses[:healthy] : ReleaseHealthEvent.health_statuses[:unhealthy]
    return if last_event.present? && last_event.health_status == current_status

    release_health_events.create(deployment_run:, release_health_rule:, health_status: current_status, event_timestamp: Time.current)
  end

  def rule_for_metric(metric_name)
    release_health_rules.for_metric(metric_name).first
  end

  def metric_healthy?(metric_name)
    raise ArgumentError, "Invalid metric name" unless metric_name.in? METRIC_VALUES.keys

    rule = rule_for_metric(metric_name)
    return unless rule

    event = deployment_run.release_health_events.where(release_health_rule: rule).last
    return true if event.blank?
    event.healthy?
  end
end

# == Schema Information
#
# Table name: release_health_events
#
#  id                       :uuid             not null, primary key
#  action_triggered         :boolean          default(FALSE)
#  event_timestamp          :datetime         not null, indexed
#  health_status            :string           not null
#  notification_triggered   :boolean          default(FALSE)
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  deployment_run_id        :uuid             not null, indexed => [release_health_rule_id, release_health_metric_id], indexed
#  release_health_metric_id :uuid             not null, indexed => [deployment_run_id, release_health_rule_id], indexed
#  release_health_rule_id   :uuid             not null, indexed => [deployment_run_id, release_health_metric_id], indexed
#
class ReleaseHealthEvent < ApplicationRecord
  include Displayable
  include Memery

  self.implicit_order_column = :event_timestamp

  enum health_status: {healthy: "healthy", unhealthy: "unhealthy"}

  belongs_to :deployment_run
  belongs_to :release_health_rule
  belongs_to :release_health_metric

  scope :for_rule, ->(rule) { where(release_health_rule: rule) }

  delegate :notify!, to: :deployment_run

  after_create_commit :notify_health_rule_triggered

  private

  def notify_health_rule_triggered
    return if previous_event.blank? && healthy?
    return if previous_event.present? && previous_event.health_status == health_status
    notify!("One of the release health rules has been triggered", :release_health_events, notification_params)
  end

  def notification_params
    deployment_run.notification_params.merge(
      {
        rule_filters:,
        rule_triggers:
      }
    )
  end

  def rule_filters
    release_health_rule.filters.map { |expr| "#{expr.metric.titleize} is #{release_health_metric.evaluate(expr.metric)}%" }
  end

  def rule_triggers
    release_health_rule.triggers.map { |expr| expr.evaluation(release_health_metric.evaluate(expr.metric)) }
  end

  memoize def previous_event
    deployment_run.release_health_events.for_rule(release_health_rule).where.not(id:).reorder("event_timestamp").last
  end
end

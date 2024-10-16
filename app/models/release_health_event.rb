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
#  deployment_run_id        :uuid             indexed => [release_health_rule_id, release_health_metric_id], indexed
#  production_release_id    :uuid             indexed => [release_health_rule_id, release_health_metric_id], indexed
#  release_health_metric_id :uuid             not null, indexed => [deployment_run_id, release_health_rule_id], indexed => [production_release_id, release_health_rule_id], indexed
#  release_health_rule_id   :uuid             not null, indexed => [deployment_run_id, release_health_metric_id], indexed => [production_release_id, release_health_metric_id], indexed
#
class ReleaseHealthEvent < ApplicationRecord
  include Displayable

  self.implicit_order_column = :event_timestamp

  enum :health_status, {healthy: "healthy", unhealthy: "unhealthy"}

  belongs_to :deployment_run, optional: true
  belongs_to :production_release, optional: true
  belongs_to :release_health_rule
  belongs_to :release_health_metric

  scope :for_rule, ->(rule) { where(release_health_rule: rule) }

  delegate :notify!, to: :parent

  after_create_commit :notify_health_rule_triggered

  private

  def parent
    deployment_run || production_release
  end

  def notify_health_rule_triggered
    return if previous_event.blank? && healthy?
    return if healthy? && parent.unhealthy?
    notify!("One of the release health rules has been triggered", :release_health_events, notification_params)
  end

  def notification_params
    parent.notification_params.merge(
      {
        release_health_rule_filters: rule_filters,
        release_health_rule_triggers: rule_triggers
      }
    )
  end

  def rule_filters
    release_health_rule.filters.map { |expr| "#{expr.metric.titleize} is #{release_health_metric.evaluate(expr.metric)}%" }
  end

  def rule_triggers
    release_health_rule.triggers.map { |expr| expr.evaluation(release_health_metric.evaluate(expr.metric)) }
  end

  def previous_event
    parent.release_health_events.for_rule(release_health_rule).where.not(id:).reorder("event_timestamp").last
  end
end

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
#  production_release_id    :uuid             indexed => [release_health_rule_id, release_health_metric_id], indexed
#  release_health_metric_id :uuid             not null, indexed => [deployment_run_id, release_health_rule_id], indexed => [production_release_id, release_health_rule_id], indexed
#  release_health_rule_id   :uuid             not null, indexed => [deployment_run_id, release_health_metric_id], indexed => [production_release_id, release_health_metric_id], indexed
#
class ReleaseHealthEvent < ApplicationRecord
  include Displayable

  self.implicit_order_column = :event_timestamp
  self.ignored_columns += ["deployment_run_id"]

  enum :health_status, {healthy: "healthy", unhealthy: "unhealthy"}

  belongs_to :production_release
  belongs_to :release_health_rule
  belongs_to :release_health_metric

  scope :for_rule, ->(rule) { where(release_health_rule: rule) }

  delegate :notify!, to: :production_release

  after_create_commit :notify_health_rule_triggered

  private

  def notify_health_rule_triggered
    return if previous_event.blank? && healthy?
    return if healthy? && production_release.unhealthy?
    notify!("One of the release health rules has been triggered", :release_health_events, notification_params)
  end

  def notification_params
    production_release.notification_params.merge(
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
    production_release.release_health_events.for_rule(release_health_rule).where.not(id:).reorder("event_timestamp").last
  end
end

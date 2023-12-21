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
  self.implicit_order_column = :event_timestamp

  enum health_status: {healthy: "healthy", unhealthy: "unhealthy"}

  belongs_to :deployment_run
  belongs_to :release_health_rule
  belongs_to :release_health_metric
end

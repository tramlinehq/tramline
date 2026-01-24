class AutomaticUpdateRolloutJob < ApplicationJob
  queue_as :high

  def perform(play_store_rollout_id, expected_timestamp = nil, expected_stage = nil)
    rollout = PlayStoreRollout.find(play_store_rollout_id)

    # no-op and don't reschedule
    return unless rollout.automatic_rollout?
    return unless rollout.started?
    return unless rollout.actionable?

    # prevents duplicate execution after pause/resume cycles
    return if expected_timestamp.present? && rollout.automatic_rollout_next_update_at&.to_i != expected_timestamp
    return if expected_stage.present? && rollout.current_stage != expected_stage

    Coordinators::IncreaseStoreRollout.call(rollout)
    rollout.schedule_next_automatic_rollout!
  end
end

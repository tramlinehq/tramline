class IncreaseHealthyReleaseRolloutJob < ApplicationJob
  queue_as :high

  def perform(play_store_rollout_id)
    rollout = PlayStoreRollout.find(play_store_rollout_id)
    # Guard clauses - no-op and don't reschedule
    return unless rollout.automatic_rollout?
    return unless rollout.started?
    return unless rollout.actionable?

    Coordinators::IncreaseStoreRollout.call(rollout)
    rollout.schedule_next_automatic_rollout!
  end
end

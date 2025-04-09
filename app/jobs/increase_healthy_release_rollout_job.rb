class IncreaseHealthyReleaseRolloutJob < ApplicationJob
  queue_as :high

  def perform(play_store_rollout_id)
    rollout = PlayStoreRollout.find(play_store_rollout_id)
    return if rollout.completed? || rollout.fully_released?
    return unless rollout.automatic_rollout?

    release = rollout.parent_release

    if release.healthy? && (rollout.started? || rollout.halted?)
      Action.increase_the_store_rollout!(rollout)
    end

    # This update is necessary so that our verify rollout job does not pick this up again
    rollout.update!(
      automatic_rollout_updated_at: Time.current,
      automatic_rollout_next_update_at: Time.current + PlayStoreRollout::AUTO_ROLLOUT_RUN_INTERVAL
    )

    IncreaseHealthyReleaseRolloutJob.perform_in(PlayStoreRollout::AUTO_ROLLOUT_RUN_INTERVAL, play_store_rollout_id)
  end
end

class IncreaseHealthyReleaseRolloutJob < ApplicationJob
  queue_as :high

  def perform(play_store_rollout_id)
    rollout = PlayStoreRollout.find(play_store_rollout_id)
    return if rollout.completed? || rollout.fully_released?
    return unless rollout.automatic_rollout?

    release = rollout.parent_release

    if release.healthy? && (rollout.started? || rollout.halted?)
      Action.increase_the_store_rollout!(rollout)
      rollout.update!(automatic_rollout_updated_at: Time.current)
    end

    IncreaseHealthyReleaseRolloutJob.perform_in(24.hours, play_store_rollout_id)
  end
end

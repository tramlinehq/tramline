class VerifyAutomaticRolloutJob < ApplicationJob
  queue_as :high

  def perform
    PlayStoreRollout.automatic_rollouts
      .where(automatic_rollout_next_update_at: ...Time.current)
      .where(
        "automatic_rollout_next_update_at - automatic_rollout_updated_at >= interval '300 second'"
      ).find_each do |rollout|
      IncreaseHealthyReleaseRolloutJob.perform_async(rollout.id)
    end
  end
end

class VerifyAutomaticRolloutJob < ApplicationJob
  queue_as :high

  def perform
    PlayStoreRollout
      .automatic_rollouts
      .where(automatic_rollout_next_update_at: ..5.minutes.ago) # should've happened more than 5m ago
      .find_each do |rollout|
      # TODO: maybe just alert for now
      IncreaseHealthyReleaseRolloutJob.perform_async(rollout.id)
    end
  end
end

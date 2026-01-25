# this is a preventative job that checks for automatic rollouts that should have progressed but haven't
class VerifyAutomaticRolloutJob < ApplicationJob
  include Loggable
  queue_as :high

  def perform
    PlayStoreRollout
      .automatic_rollouts
      .where(automatic_rollout_next_update_at: ..5.minutes.ago) # should've happened more than 5m ago
      .find_each do |rollout|
      elog("Automatic rollout #{rollout.id} did not auto-update at #{rollout.automatic_rollout_next_update_at}", level: :warn)
      AutomaticUpdateRolloutJob.perform_async(rollout.id, rollout.automatic_rollout_next_update_at.to_i, rollout.current_stage)
    end
  end
end

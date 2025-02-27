class IncreaseHealthyReleaseRolloutsJob < ApplicationJob
  queue_as :high

  def perform
    # Increase rollout for active Play Store rollouts with healthy releases
    StoreRollout.active.where(type: "PlayStoreRollout").each do |store_rollout|
      release = store_rollout.parent_release

      # Skip if the release is unhealthy
      next if release.unhealthy?

      # Increase the rollout percentage for healthy releases
      Action.increase_the_store_rollout!(store_rollout)
    end

    # Start rollout for prepared app store submissions that have a created rollout
    PlayStoreSubmission.where(status: "prepared").each do |submission|
      release = submission.parent_release

      # Skip if the release is unhealthy
      next if release.unhealthy?

      # Get the rollout for this submission
      rollout = submission.store_rollout

      # Skip if no rollout exists or if it's already active/completed
      next if rollout.nil? || !rollout.created?

      # Start the rollout for this approved submission
      Action.start_the_store_rollout!(rollout)
    end
  end
end

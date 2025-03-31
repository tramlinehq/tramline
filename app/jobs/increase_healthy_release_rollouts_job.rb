class IncreaseHealthyReleaseRolloutsJob < ApplicationJob
  queue_as :high

  def perform
    PlayStoreRollout.automatic_rollouts_enabled.find_each do |store_rollout|
      release = store_rollout.parent_release

      if store_rollout.created?
        Action.start_the_store_rollout!(store_rollout)
      elsif store_rollout.started?
        next if release.unhealthy?
        Action.increase_the_store_rollout!(store_rollout)
      end
    end
  end
end

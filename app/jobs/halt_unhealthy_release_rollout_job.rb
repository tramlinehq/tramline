class HaltUnhealthyReleaseRolloutJob < ApplicationJob
  queue_as :high

  def perform(production_release_id)
    production_release = ProductionRelease.find(production_release_id)

    if production_release.unhealthy?
      store_rollout = production_release.store_rollout

      if store_rollout.is_a?(PlayStoreRollout) && store_rollout.automatic_rollout?
        Action.halt_the_store_rollout!(store_rollout)
        store_rollout.update!(
          automatic_rollout_updated_at: Time.current,
          automatic_rollout_next_update_at: Time.current + PlayStoreRollout::AUTO_ROLLOUT_RUN_INTERVAL
        )
      end
    end
  end
end

class HaltUnhealthyReleaseRolloutJob < ApplicationJob
  queue_as :high

  def perform(production_release_id, event_id)
    production_release = ProductionRelease.find(production_release_id)
    event = ReleaseHealthEvent.find(event_id)

    if production_release.unhealthy?
      store_rollout = production_release.store_rollout

      if store_rollout.is_a?(PlayStoreRollout) && store_rollout.automatic_rollout?
        result = Action.halt_the_store_rollout!(store_rollout)

        # Mark the event as action triggered if halt was successful
        event.update(action_triggered: true) if result.ok?
      end
    end
  end
end

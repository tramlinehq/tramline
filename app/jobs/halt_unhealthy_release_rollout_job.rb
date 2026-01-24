class HaltUnhealthyReleaseRolloutJob < ApplicationJob
  queue_as :high

  def perform(production_release_id, event_id)
    production_release = ProductionRelease.find(production_release_id)
    event = ReleaseHealthEvent.find(event_id)

    if production_release.unhealthy?
      store_rollout = production_release.store_rollout

      if store_rollout.is_a?(PlayStoreRollout) && store_rollout.staged_rollout?
        Coordinators::HaltStoreRollout.call(store_rollout)
        event.update(action_triggered: true)
      end
    end
  end
end

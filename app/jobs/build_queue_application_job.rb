class BuildQueueApplicationJob < ApplicationJob
  include Loggable

  queue_as :high

  def perform(build_queue_id)
    build_queue = BuildQueue.find_by(id: build_queue_id)
    return unless build_queue.release.committable?
    return unless build_queue.is_active?

    if build_queue.release.is_v2?
      Signal.build_queue_can_be_applied!(build_queue)
    else
      build_queue.release.with_lock do
        return unless build_queue.release.committable?
        return unless build_queue.is_active?
        build_queue.apply!
      end
    end
  end
end

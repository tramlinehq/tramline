class BuildQueueApplicationJob < ApplicationJob
  include Loggable

  queue_as :high

  def perform(build_queue_id)
    build_queue = BuildQueue.find_by(id: build_queue_id)
    return unless build_queue.release.committable?
    return unless build_queue.is_active?

    Signal.build_queue_can_be_applied!(build_queue)
  end
end

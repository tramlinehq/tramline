class Releases::PostReleaseJob < ApplicationJob
  queue_as :high

  def perform(train_run_id)
    run = Releases::Train::Run.find(train_run_id)
    return unless run.finalizable?
    Triggers::PostRelease.call(run)
  end
end

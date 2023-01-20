class Releases::PostReleaseJob < ApplicationJob
  queue_as :high

  def perform(train_run_id)
    run = Releases::Train::Run.find(train_run_id)
    run.with_lock do
      return unless run.finalizable?
      Triggers::PostRelease.call(run)
      run.event_stamp!(reason: :finalizing, kind: :notice, data: {version: run.release_version})
    end
  end
end

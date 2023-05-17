class Releases::PreReleaseJob < ApplicationJob
  queue_as :high

  def perform(train_run_id)
    sleep 2
    run = Releases::Train::Run.find(train_run_id)
    Triggers::PreRelease.call(run)
  end
end

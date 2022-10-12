class Releases::PostReleaseJob < ApplicationJob
  queue_as :high

  def perform(train_run_id)
    Triggers::PostRelease.call(Releases::Train::Run.find(train_run_id))
  end
end

class Releases::PostReleaseGroupJob < ApplicationJob
  queue_as :high

  def perform(train_group_run_id)
    run = Releases::TrainGroup::Run.find(train_group_run_id)
    Triggers::PostReleaseGroup.call(run)
  end
end

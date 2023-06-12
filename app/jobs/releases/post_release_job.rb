class Releases::PostReleaseJob < ApplicationJob
  queue_as :high

  def perform(train_run_id)
    run = Releases::Train::Run.find(train_run_id)

    if run.train_group_run.present?
      run.finish!
    else
      Triggers::PostRelease.call(run)
    end
  end
end

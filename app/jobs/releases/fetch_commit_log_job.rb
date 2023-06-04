class Releases::FetchCommitLogJob < ApplicationJob
  queue_as :high

  def perform(train_run_id)
    run = Releases::Train::Run.find(train_run_id)
    run.fetch_commit_log
  end
end

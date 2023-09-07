class Releases::PostReleaseJob < ApplicationJob
  queue_as :high

  def perform(release_id, force_finalize = false)
    run = Release.find(release_id)

    Triggers::PostRelease.call(run, force_finalize)
  end
end

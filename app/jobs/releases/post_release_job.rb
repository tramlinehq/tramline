class Releases::PostReleaseJob < ApplicationJob
  queue_as :high

  def perform(release_id)
    run = Release.find(release_id)

    Triggers::PostRelease.call(run)
  end
end

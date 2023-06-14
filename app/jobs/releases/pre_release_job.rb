class Releases::PreReleaseJob < ApplicationJob
  queue_as :high

  def perform(release_id)
    run = Release.find(release_id)
    Triggers::PreRelease.call(run)
  end
end

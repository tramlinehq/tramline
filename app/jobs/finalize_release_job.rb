class FinalizeReleaseJob < ApplicationJob
  queue_as :high

  def perform(release_id, force_finalize = false)
    release = Release.find(release_id)
    return unless release.ready_to_be_finalized?
    Coordinators::FinalizeRelease.call(release, force_finalize)
  end
end

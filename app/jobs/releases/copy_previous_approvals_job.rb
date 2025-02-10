class Releases::CopyPreviousApprovalsJob < ApplicationJob
  queue_as :high

  def perform(release_id)
    release = Release.find(release_id)
    release.copy_previous_approvals if release.copy_approvals_allowed?
  end
end

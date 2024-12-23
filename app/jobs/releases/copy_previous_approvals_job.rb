class Releases::CopyPreviousApprovalsJob < ApplicationJob
  queue_as :default

  def perform(release_id)
    release = Release.find_by(id: release_id)
    unless release
      Rails.logger.error("Release with ID #{release_id} not found")
      return
    end

    release.copy_previous_approvals if release.copy_approvals_allowed?
  end
end

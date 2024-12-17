class CreateVersionTagJob < ApplicationJob
  queue_as :default

  def perform(commit_hash, version, working_branch, vcs_provider)
    Triggers::Trunk.call(commit_hash, version, working_branch, vcs_provider)
  rescue Installations::Github::Error => e
    Rails.logger.error("Failed to create version tag: #{e.message}")
    raise
  end
end

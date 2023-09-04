class WebhookProcessors::PullRequest < ApplicationJob
  queue_as :high

  def perform(release_id, pr_attributes)
    Release.find(release_id)
      .pull_requests
      .where(number: pr_attributes[:number])
      .each { |pr| pr.update_or_insert!(pr_attributes) }
  end
end

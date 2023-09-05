class WebhookProcessors::PullRequestJob < ApplicationJob
  queue_as :high

  # FIXME: We treat "closed" and "merged" as the same thing
  def perform(train_id, pr_attributes)
    head_ref = pr_attributes[:head_ref]
    number = pr_attributes[:number]

    Train.find(train_id).open_active_prs_for(head_ref).where(number:).each do |pr|
      pr.update_or_insert!(pr_attributes)
      pr.release.event_stamp!(reason: :pr_merged, kind: :success, data: {url: pr.url, number: pr.number, base_branch: pr.base_ref})
    end
  end
end

class Webhooks::ClosePullRequestJob < ApplicationJob
  queue_as :high

  # TODO: retry finalize release if a post-release PR is closed
  def perform(train_id, pr_attributes)
    head_ref = pr_attributes[:head_ref]
    number = pr_attributes[:number]

    Train.find(train_id).open_active_prs_for(head_ref).where(number:).find_each do |pr|
      pr.update_or_insert!(pr_attributes)
      pr.release.event_stamp!(reason: :pr_merged, kind: :success, data: {url: pr.url, number: pr.number, base_branch: pr.base_ref})
      Action.complete_release!(pr.release) if pr.post_release?
    end
  end
end

class Webhooks::ClosePullRequestJob < ApplicationJob
  queue_as :high

  def perform(train_id, pr_attributes)
    pr_attributes = pr_attributes.with_indifferent_access
    head_ref = pr_attributes[:head_ref]
    number = pr_attributes[:number]

    Train.find(train_id).open_active_prs_for(head_ref).where(number:).find_each do |pr|
      pr.update_or_insert!(pr_attributes)
      pr.stamp_merge!
      pr.reload
      Signal.pull_request_closed!(pr)
    end
  end
end

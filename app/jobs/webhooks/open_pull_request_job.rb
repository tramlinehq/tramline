class Webhooks::OpenPullRequestJob < ApplicationJob
  queue_as :high

  def perform(train_id, pr_attributes)
    pr_attributes = pr_attributes.with_indifferent_access
    base_ref = pr_attributes[:base_ref]

    train = Train.find(train_id)
    release = train.active_runs.where(branch_name: base_ref).sole

    return unless release

    pr_attributes[:release_id] = release.id
    pr_attributes[:phase] = :mid_release
    pr_attributes[:kind] = :stability
    pr_attributes[:state] = :open
    PullRequest.update_or_insert!(pr_attributes)
  end
end

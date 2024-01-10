class WebhookProcessors::OpenPullRequestJob < ApplicationJob
  queue_as :high

  def perform(train_id, pr_attributes)
    Rails.logger.debug "Create/update PR with attributes", pr_attributes

    base_ref = pr_attributes[:base_ref]

    train = Train.find(train_id)
    release = train.active_runs.where(branch_name: base_ref).sole

    return unless release

    pr = release.pull_requests.mid_release.open.build
    pr.update_or_insert!(pr_attributes)
  end
end

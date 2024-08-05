# frozen_string_literal: true

class V2::LiveRelease::CurrentPreProdReleaseComponent < V2::BaseComponent
  STATUS = {
    created: {text: "Ongoing", status: :routine},
    failed: {text: "Failed", status: :failure},
    finished: {text: "Finished", status: :success}
  }

  def initialize(pre_prod_release)
    @pre_prod_release = pre_prod_release
  end

  attr_reader :pre_prod_release
  delegate :release_platform_run, :store_submissions, :workflow_run, :build, to: :pre_prod_release

  def changed_commits
    V2::CommitComponent.with_collection(pre_prod_release.commits_since_previous)
  end

  def status
    (STATUS[pre_prod_release.status.to_sym] || {text: pre_prod_release.status.humanize, status: :neutral}).merge(kind: :status)
  end

  def triggerable?
    workflow_run&.created?
  end

  def retriggerable?
    workflow_run&.may_retry?
  end
end

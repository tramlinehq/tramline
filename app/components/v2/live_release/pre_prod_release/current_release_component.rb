# frozen_string_literal: true

class V2::LiveRelease::PreProdRelease::CurrentReleaseComponent < V2::BaseComponent
  include Memery

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

  memoize def latest_internal_release
    release_platform_run.latest_internal_release(finished: true)
  end

  memoize def latest_commit
    release_platform_run.last_commit
  end

  def rc_params
    if pre_prod_release.carried_over?
      {build_id: latest_internal_release.build.id}
    else
      {commit_id: latest_commit.id}
    end
  end
end

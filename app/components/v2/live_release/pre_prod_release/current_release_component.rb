# frozen_string_literal: true

class V2::LiveRelease::PreProdRelease::CurrentReleaseComponent < V2::BaseComponent
  include Memery

  STATUS = {
    created: {text: "In progress", status: :routine},
    failed: {text: "Failed", status: :failure},
    finished: {text: "Success", status: :success}
  }

  def initialize(pre_prod_release)
    @pre_prod_release = pre_prod_release
  end

  attr_reader :pre_prod_release
  delegate :release_platform_run,
    :store_submissions,
    :workflow_run,
    :conf,
    :build, to: :pre_prod_release

  def show_blocked_message?
    release_platform_run.play_store_blocked? && store_submissions.none?(&:failed_with_action_required?)
  end

  def changed_commits
    pre_prod_release.commits_since_previous
  end

  def status
    status_picker(STATUS, pre_prod_release.status).merge(kind: :status)
  end

  def triggerable?
    workflow_run&.created?
  end

  def retriggerable?
    workflow_run&.may_retry?
  end

  def latest_internal_release
    release_platform_run.latest_internal_release(finished: true)
  end

  def latest_commit
    release_platform_run.last_commit
  end
end

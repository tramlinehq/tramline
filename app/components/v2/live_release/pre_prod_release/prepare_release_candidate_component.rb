# frozen_string_literal: true

class V2::LiveRelease::PreProdRelease::PrepareReleaseCandidateComponent < V2::BaseComponent
  def initialize(release_platform_run)
    @release_platform_run = release_platform_run
    @latest_internal_release = release_platform_run.latest_internal_release(finished: true)
  end

  attr_reader :release_platform_run, :latest_internal_release
  delegate :build, to: :latest_internal_release, allow_nil: true
  delegate :ready_for_beta_release?, to: :release_platform_run

  def title
    if carryover_build?
      "Active Release Candidate"
    else
      "Latest Change"
    end
  end

  def applicable_commit
    release_platform_run.release.last_applicable_commit
  end

  def create_new_rc?
    return unless ready_for_beta_release?
    release_platform_run.conf.workflows.separate_rc_workflow? && applicable_commit.present?
  end

  def carryover_build?
    return unless ready_for_beta_release?
    !release_platform_run.conf.workflows.separate_rc_workflow? && latest_internal_release.present?
  end

  def confirmation_opts
    html_opts(:post, "Are you sure you want to start the beta release?")
  end

  def create_release_candidate_path
    pre_prod_beta_run_path(release_platform_run)
  end
end

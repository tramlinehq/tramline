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

  def commit
    release_platform_run.last_commit
  end

  def create_new_rc?
    return unless ready_for_beta_release?
    release_platform_run.conf.workflows.separate_rc_workflow? && commit.present?
  end

  def carryover_build?
    return unless ready_for_beta_release?
    !release_platform_run.conf.workflows.separate_rc_workflow? && latest_internal_release.present?
  end

  def confirmation_opts
    rc_params =
      if carryover_build?
        {build_id: build.id}
      else
        {commit_id: commit.id}
      end

    html_opts(:post, "Are you sure you want to start the beta release?", params: {pre_prod_release: rc_params})
  end

  def create_release_candidate_path
    run_pre_prod_beta_path(release_platform_run)
  end
end

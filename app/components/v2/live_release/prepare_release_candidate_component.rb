# frozen_string_literal: true

class V2::LiveRelease::PrepareReleaseCandidateComponent < V2::BaseComponent
  def initialize(release_platform_run)
    @release_platform_run = release_platform_run
    @latest_internal_release = release_platform_run.latest_internal_release(finished: true)
  end

  delegate :build, to: :@latest_internal_release, allow_nil: true

  def title
    if carryover_build?
      "Latest Internal Build"
    else
      "Latest Change"
    end
  end

  def commit
    @latest_internal_release.build.commit || @release_platform_run.last_commit
  end

  def carryover_build?
    @latest_internal_release.present? && !@release_platform_run.conf.workflows.separate_rc_workflow?
  end

  def confirmation_opts
    {
      method: :post,
      params: {pre_prod_release: rc_params},
      data: {turbo_method: :post, turbo_confirm: "Are you sure?"}
    }
  end

  def create_release_candidate_path
    run_pre_prod_beta_path(@release_platform_run)
  end

  def rc_params
    if carryover_build?
      {build_id: build.id}
    else
      {commit_id: commit.id}
    end
  end
end

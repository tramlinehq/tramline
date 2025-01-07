# frozen_string_literal: true

class V2::LiveRelease::PreProdRelease::RcHeaderComponent < V2::LiveRelease::PreProdRelease::HeaderComponent
  def workflow_config
    release_platform_run.conf.release_candidate_workflow
  end

  def builds
    release_platform_run.rc_builds.includes(:external_build)
  end
end

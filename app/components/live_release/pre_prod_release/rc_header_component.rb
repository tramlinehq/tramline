# frozen_string_literal: true

class LiveRelease::PreProdRelease::RcHeaderComponent < LiveRelease::PreProdRelease::HeaderComponent
  def workflow_config
    release_platform_run.conf.release_candidate_workflow
  end

  def builds
    release_platform_run.rc_builds.includes(:external_build)
  end
end

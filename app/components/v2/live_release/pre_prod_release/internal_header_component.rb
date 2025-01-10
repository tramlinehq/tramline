# frozen_string_literal: true

class V2::LiveRelease::PreProdRelease::InternalHeaderComponent < V2::LiveRelease::PreProdRelease::HeaderComponent
  def workflow_config
    release_platform_run.conf.pick_internal_workflow
  end

  def builds
    release_platform_run.internal_builds.includes(:external_build)
  end
end

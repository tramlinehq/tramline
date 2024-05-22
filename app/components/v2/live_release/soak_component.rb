class V2::LiveRelease::SoakComponent < V2::BaseComponent
  def initialize(release)
    @release = release
    @release_platform_runs = release.release_platform_runs
  end
end

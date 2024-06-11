class V2::LiveRelease::SoakComponent < V2::BaseComponent
  def initialize(release, status: nil)
    @release = release
    @release_platform_runs = release.release_platform_runs
    @status = status
  end

  def success?
    @status == :success
  end
end

class V2::PlatformViewComponent < V2::BaseReleaseComponent
  def initialize(release, occupy: true)
    @release = release
    @occupy = occupy
    super(@release)
  end

  def grid_size
    return "grid-cols-2" if platform_runs.size > 1
    return "grid-cols-1" if @occupy
    "grid-cols-1 w-2/3"
  end

  def runs
    platform_runs.each do |run|
      yield(run)
    end
  end
end

class V2::PlatformLevelOverviewComponent < V2::BaseReleaseComponent
  def initialize(release, size: :sm)
    @release = release
    @size = size
    super(@release)
  end

  attr_reader :size

  def show_ci_info
    @size != :xs
  end

  def grid_size
    return "grid-cols-2" if platform_runs.size > 1
    "grid-cols-1 w-2/3"
  end
end

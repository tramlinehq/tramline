class V2::LiveRelease::RolloutComponent < V2::BaseComponent
  def initialize(release_platform_run)
    @release_platform_run = release_platform_run
  end

  attr_reader :release_platform_run

  def monitoring_size
    release_platform_run.app.cross_platform? ? :compact : :default
  end
end

class V2::LiveRelease::RolloutComponent < V2::BaseComponent
  def initialize(release_platform_run)
    @release_platform_run = release_platform_run
  end

  attr_reader :release_platform_run

  def monitoring_size
    release_platform_run.app.cross_platform? ? :compact : :default
  end

  def events
    [{
      timestamp: time_format(1.day.ago, with_year: false),
      title: "Rollout increase",
      description: "The staged rollout for this release has been increased to 50%",
      type: :success
    },
     {
       timestamp: time_format(2.day.ago, with_year: false),
       title: "Rollout increase",
       description: "The staged rollout for this release has been increased to 20%",
       type: :success
     },
     {
       timestamp: time_format(3.day.ago, with_year: false),
       title: "Rollout increase",
       description: "The staged rollout for this release has been increased to 10%",
       type: :success
     },
     {
       timestamp: time_format(4.day.ago, with_year: false),
       title: "Rollout increase",
       description: "The staged rollout for this release has been increased to 1%",
       type: :success
     }]
  end
end

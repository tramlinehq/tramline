class LiveRelease::RegressionTestingComponent < BaseComponent
  def initialize(release_platform_run)
    @release_platform_run = release_platform_run
  end

  attr_reader :release_platform_run
  delegate :release, to: :release_platform_run

  def events
    [
      {
        timestamp: time_format(1.day.ago, with_year: false),
        description: "Build #239 was rejected by Derek O' Brien",
        type: :error
      },
      {
        timestamp: time_format(2.days.ago, with_year: false),
        description: "Build #238 was approved by Akhil Vaidya",
        type: :success
      },
      {
        timestamp: time_format(3.days.ago, with_year: false),
        description: "Build #237 was approved by Sagar Neeraj",
        type: :success
      }
    ]
  end

  def testing_status
    [
      {text: "In progress", status: :ongoing},
      {text: "Rejected", status: :failure},
      {text: "Approved", status: :success}
    ].sample
  end
end

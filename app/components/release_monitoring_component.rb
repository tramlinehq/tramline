class ReleaseMonitoringComponent < ViewComponent::Base
  attr_reader :release

  def initialize(release:)
    @release = release
  end
end

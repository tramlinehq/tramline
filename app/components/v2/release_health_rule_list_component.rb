class V2::ReleaseHealthRuleListComponent < V2::BaseComponent
  def initialize(release_platform:)
    @release_platform = release_platform
  end

  attr_reader :release_platform
  delegate :train, :app, to: :release_platform

  def empty?
    release_platform.release_health_rules.none?
  end
end

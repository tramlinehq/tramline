class V2::RuleListComponent < V2::BaseComponent
  include Memery

  def initialize(release_platform:)
    @release_platform = release_platform
  end

  attr_reader :release_platform
  delegate :train, :app, to: :release_platform

  def empty?
    release_platform.release_health_rules.none?
  end
end

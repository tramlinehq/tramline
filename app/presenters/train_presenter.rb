class TrainPresenter < SimpleDelegator
  VERSIONING_STRATEGIES = {
    "SemVer" => :semver,
    "CalVer" => :calver
  }

  if Set.new(VERSIONING_STRATEGIES.values) != Set.new(VersioningStrategies::Semverish::STRATEGIES.keys)
    raise ArgumentError, "Displayable versioning strategies do not match the ones specified in Semverish"
  end

  def initialize(train, view_context = nil)
    @view_context = view_context
    super(train)
  end
end

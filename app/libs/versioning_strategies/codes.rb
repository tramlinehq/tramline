class VersioningStrategies::Codes
  using RefinedString

  STRATEGIES = {
    increment: proc { |v|
      value = v[:value].to_i
      (!value.nil?) ? value.abs + 1 : 0
    },

    semver_pairs_with_build_sequence: proc { |v|
      value = v[:value].to_i
      semver = v[:release_version].to_semverish
      raise ArgumentError.new("could not bump version code because release version is not a valid semver") if semver.nil?
      initial_digit = 9
      major, minor, patch = semver.major, semver.minor, semver.patch || 0
      new_build_number = (initial_digit * 100_000_000) + (major * 1_000_000) + (minor * 10_000) + (patch * 100)
      new_build_number = new_build_number.succ while new_build_number <= value
      new_build_number || 0
    }
  }

  DEFAULT_STRATEGY = :increment

  def self.bump(params, strategy: DEFAULT_STRATEGY)
    new(params).bump(strategy:)
  end

  def initialize(params)
    raise ArgumentError.new("not a valid version code") if params.is_a?(Hash) && params[:value].blank?
    @params = params
  end

  def bump(strategy: DEFAULT_STRATEGY)
    bumped_value = STRATEGIES[strategy].call(@params)
    raise ArgumentError.new("could not bump version code") if bumped_value.nil?
    bumped_value
  end
end

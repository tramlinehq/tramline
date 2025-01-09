# Semverish represents a loose/broad range of what we allow in the x.y.z versioning system
# It bumps and validates in a more tight/specific way depending on the strategy used
class VersioningStrategies::Semverish
  include Comparable

  SEMVER = VersioningStrategies::Semverish::Semver
  CALVER = VersioningStrategies::Semverish::Calver
  DEFAULT_STRATEGY = :semver
  # adapted from https://semver.org/#is-there-a-suggested-regular-expression-regex-to-check-a-semver-string
  # - makes the patch version optional
  # - removes support for the prerelease version and the build metadata
  # - allows zero-padded numbers for minor and patch
  SEMVERISH_REGEX = /\A(0|[1-9]\d*)\.(0|[1-9]\d*|0\d)(?:\.(0|[1-9]\d*|0\d+))?\Z/

  def self.build(major, minor, patch)
    raise ArgumentError, "Cannot build a Semverish without a minor" if major.present? && patch.present? && minor.blank?
    new([major, minor, patch].compact_blank.join("."))
  end

  def initialize(version_str)
    v = version_str&.match(SEMVERISH_REGEX)
    raise ArgumentError, "#{version_str} is not a valid Semverish" if v.nil?

    @version = version_str
    @major = v[1]
    @minor = v[2]
    @patch = v[3]
  end

  attr_reader :major, :minor, :patch, :version

  def bump!(term, strategy: DEFAULT_STRATEGY)
    bump_strategy =
      case strategy
      when :semver then SEMVER.new(major, minor, patch).bump!(term)
      when :calver then CALVER.new(major, minor, patch).bump!(term)
      else raise ArgumentError, "Unknown strategy: #{strategy}"
      end

    VersioningStrategies::Semverish.build(bump_strategy.major, bump_strategy.minor, bump_strategy.patch)
  end

  def valid?(strategy: DEFAULT_STRATEGY)
    case strategy
    when :semver then SEMVER.valid?(version)
    when :calver then CALVER.valid?(version)
    else raise ArgumentError, "Unknown strategy: #{strategy}"
    end
  end

  def <=>(other)
    other = new(other) if other.is_a? String

    if other.partial? != partial?
      raise ArgumentError.new("cannot compare #{version} with version #{other.version}")
    end

    [:major, :minor, (proper? ? :patch : nil)].compact.each do |part|
      c = (public_send(part).to_i <=> other.public_send(part).to_i)

      if c != 0
        return c
      end
    end

    0
  end

  def to_s(patch_glob: false)
    parts = to_a.take((partial? || patch_glob) ? 2 : 3)
    parts << "*" if patch_glob && !partial?
    parts.join(".")
  end

  def to_a
    [@major, @minor, @patch].compact
  end

  delegate :hash, to: :to_a

  def to_h
    [:major, :minor, :patch].zip(to_a).to_h
  end

  def eql?(other)
    hash == other.hash
  end

  def partial? = !proper?

  def proper? = !@patch.nil?
end

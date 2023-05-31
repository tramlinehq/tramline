class VersioningStrategies::Semverish
  include Comparable

  TEMPLATES = {
    pn: "Positive Number",
    yyyy: "Current Year"
  }

  INCREMENTS = {
    pn: proc { |v| (!v.nil?) ? v + 1 : nil },
    yyyy: proc { |_v| Time.current.year }
  }

  DEFAULT_TEMPLATE = :pn

  # This is a modified semver regex that makes the patch version, the prerelease version and the build metadata optional
  SEMVER_REGEX = /\A(0|[1-9]\d*)\.(0|[1-9]\d*)(?:\.(0|[1-9]\d*))?(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][a-zA-Z0-9-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][a-zA-Z0-9-]*))*))?(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?\Z/

  attr_accessor :major, :minor, :patch, :pre, :build
  attr_reader :version

  def initialize(version_str)
    v = version_str.match(SEMVER_REGEX)

    raise ArgumentError.new("#{version_str} is not a valid Semverish") if v.nil?

    @major = v[1].to_i
    @minor = v[2].to_i
    @patch = v[3].presence && v[3].to_i
    @pre = v[4]
    @build = v[5]
    @version = version_str
    @is_proper_semver = !@patch.nil?
  end

  def increment!(term, template_type: DEFAULT_TEMPLATE)
    term = term.to_sym
    new_version = clone
    new_value = INCREMENTS[template_type].call(send(term))
    new_version.send("#{term}=", new_value)
    new_version.minor = 0 if term == :major
    new_version.patch = 0 if semver? && (term == :major || term == :minor)
    new_version.build = new_version.pre = nil
    new_version
  end

  def <=>(other)
    other = new(other) if other.is_a? String

    if other.partial_semver? != partial_semver?
      raise ArgumentError.new("cannot compare #{@version} with partial version #{other.version}")
    end

    [:major, :minor, (semver? ? :patch : nil)].compact.each do |part|
      c = (send(part) <=> other.send(part))

      if c != 0
        return c
      end
    end

    0
  end

  def to_a
    [@major, @minor, @patch].compact
  end

  def to_s
    to_a.join "."
  end

  def to_h
    keys = [:major, :minor, :patch]
    keys.zip(to_a).to_h
  end

  def hash
    to_a.hash
  end

  def eql?(other)
    hash == other.hash
  end

  def partial_semver?
    !semver?
  end

  def semver?
    !@patch.nil?
  end
end

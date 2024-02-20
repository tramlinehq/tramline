class VersioningStrategies::Semverish
  include Comparable

  TEMPLATES = {
    "Positive Number" => :pn,
    "Calendar Year And Next Week" => :yy0w1
  }

  INCREMENTS = {
    TEMPLATES["Positive Number"] => proc { |v| (!v.nil?) ? v.abs + 1 : nil },
    TEMPLATES["Calendar Year And Next Week"] => proc { |_v|
      now = Time.current
      Integer("#{now.year.to_s[2..3]}#{now.strftime("%U").to_i + 1}")
    }
  }

  STRATEGIES = {
    semver: {
      major: TEMPLATES["Positive Number"],
      minor: TEMPLATES["Positive Number"],
      patch: TEMPLATES["Positive Number"],
      update_minor_on_major_bump: false
    },

    year_and_next_week: {
      major: TEMPLATES["Positive Number"],
      minor: TEMPLATES["Calendar Year And Next Week"],
      patch: TEMPLATES["Positive Number"],
      update_minor_on_major_bump: true
    }
  }

  DEFAULT_STRATEGY = :semver

  # adapted from https://semver.org/#is-there-a-suggested-regular-expression-regex-to-check-a-semver-string
  # makes the patch version optional
  # and removes support for the prerelease version and the build metadata
  SEMVER_REGEX = /\A(0|[1-9]\d*)\.(0|[1-9]\d*)(?:\.(0|[1-9]\d*))?\Z/

  attr_accessor :major, :minor, :patch
  attr_reader :version

  def self.build(major, minor, patch)
    raise ArgumentError.new("Cannot build a Semverish without a minor") if major.present? && patch.present? && minor.blank?
    new([major, minor, patch].compact_blank.join("."))
  end

  def initialize(version_str)
    v = version_str&.match(SEMVER_REGEX)
    raise ArgumentError.new("#{version_str} is not a valid Semverish") if v.nil?

    @major = v[1].to_i
    @minor = v[2].to_i
    @patch = v[3].presence && v[3].to_i
    @version = version_str
  end

  def bump!(term, strategy: DEFAULT_STRATEGY)
    term = term.to_sym
    new_version = clone
    strategy_config = STRATEGIES[strategy.to_sym]
    new_value = INCREMENTS[strategy_config[term]].call(public_send(term))
    new_version.public_send("#{term}=", new_value)
    if term == :major
      new_version.minor = 0 unless strategy_config[:update_minor_on_major_bump]
      new_version.minor = INCREMENTS[strategy_config[:minor]].call(public_send(:minor)) if strategy_config[:update_minor_on_major_bump]
    end
    new_version.patch = 0 if proper? && (term == :major || term == :minor)
    new_version
  end

  def <=>(other)
    other = new(other) if other.is_a? String

    if other.partial? != partial?
      raise ArgumentError.new("cannot compare #{version} with version #{other.version}")
    end

    [:major, :minor, (proper? ? :patch : nil)].compact.each do |part|
      c = (public_send(part) <=> other.public_send(part))

      if c != 0
        return c
      end
    end

    0
  end

  def to_a
    [@major, @minor, @patch].compact
  end

  def to_s(patch_glob: false)
    to_a
      .take((partial? || patch_glob) ? 2 : 3)
      .concat([(patch_glob && !partial?) ? "*" : nil])
      .compact
      .join(".")
  end

  def to_h
    keys = [:major, :minor, :patch]
    keys.zip(to_a).to_h
  end

  delegate :hash, to: :to_a

  def eql?(other)
    hash == other.hash
  end

  def partial?
    !proper?
  end

  def proper?
    !@patch.nil?
  end
end

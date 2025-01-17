class VersioningStrategies::Semverish::Calver
  include Comparable

  CALVER_REGEX = /\A([1-9]\d{3})\.(0[1-9]|1[0-2])\.(0[1-9]|[12]\d|3[01])(0[1-9]|[1-9]\d)?\Z/

  def self.valid?(v)
    v&.match?(CALVER_REGEX)
  end

  def initialize(major, minor, patch)
    @major = major.to_s
    @minor = minor.to_s
    @patch = patch.to_s
  end

  attr_accessor :major, :minor, :patch, :seq_number

  def bump!(term)
    term = term.to_sym
    new_version = clone

    case term
    when :major
      new_version.major = year
      new_version.minor = month
      new_version.patch = day
    when :minor
      new_version.major = year
      new_version.minor = month
      new_version.patch = day
    when :patch
      new_version.patch = inc(new_version.patch)
    else
      raise
    end

    new_version
  end

  def inc(v)
    day = v[0..1].to_i
    seq = v[2..].to_i
    inc = seq.zero? ? 1 : seq.abs + 1

    "#{zero_pad(day)}#{zero_pad(inc)}"
  end

  private

  def day
    zero_pad Time.current.day
  end

  def month
    zero_pad Time.current.month
  end

  def year
    Time.current.year
  end

  def zero_pad(v)
    format("%02d", v)
  end
end

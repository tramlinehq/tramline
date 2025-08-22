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

  def bump!(term, relative_time = Time.current)
    term = term.to_sym
    new_version = clone

    case term
    when :major
      new_version.major = year(relative_time)
      new_version.minor = month(relative_time)
      new_version.patch = day(relative_time)
    when :minor
      new_version.major = year(relative_time)
      new_version.minor = month(relative_time)
      new_version.patch = day(relative_time)
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

  def day(relative_time)
    zero_pad(relative_time.day)
  end

  def month(relative_time)
    zero_pad(relative_time.month)
  end

  def year(relative_time)
    zero_pad(relative_time.year)
  end

  def zero_pad(v)
    format("%02d", v)
  end
end

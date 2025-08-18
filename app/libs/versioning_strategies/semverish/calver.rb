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

  def bump!(term, offset_duration)
    term = term.to_sym
    new_version = clone
    offset_duration = offset_duration.to_i

    case term
    when :major
      new_version.major = year offset_duration
      new_version.minor = month offset_duration
      new_version.patch = day offset_duration
    when :minor
      new_version.major = year offset_duration
      new_version.minor = month offset_duration
      new_version.patch = day offset_duration
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

  def day offset_duration
    zero_pad(offset_time(offset_duration).day)
  end

  def month offset_duration
    zero_pad(offset_time(offset_duration).month)
  end

  def year offset_duration
    offset_time(offset_duration).year
  end

  def offset_time offset_duration
    @offset_time ||= Time.current + offset_duration
  end

  def zero_pad(v)
    format("%02d", v)
  end
end

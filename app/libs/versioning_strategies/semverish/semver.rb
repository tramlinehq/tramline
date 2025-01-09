class VersioningStrategies::Semverish::Semver
  include Comparable

  SEMVER_REGEX = /\A(0|[1-9]\d*)\.(0|[1-9]\d*)(?:\.(0|[1-9]\d*))?\Z/

  def self.valid?(v)
    v.match?(SEMVER_REGEX)
  end

  def initialize(major, minor, patch)
    @major = major.to_i
    @minor = minor.to_i
    @patch = patch.presence && patch.to_i
  end

  attr_accessor :major, :minor, :patch

  def bump!(term)
    term = term.to_sym
    new_version = clone
    new_value = inc(public_send(term))
    new_version.public_send(:"#{term}=", new_value)
    new_version.minor = 0 if term == :major
    new_version.patch = 0 if proper? && (term == :major || term == :minor)
    new_version
  end

  def inc(v)
    (!v.nil?) ? v.abs + 1 : nil
  end

  private

  def proper? = !@patch.nil?
end

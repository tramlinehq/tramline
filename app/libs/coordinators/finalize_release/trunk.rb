class Coordinators::FinalizeRelease::Trunk
  def self.call(release)
    new(release).call
  end

  def initialize(release)
    @release = release
  end

  def call
    GitHub::Result.new { release.create_release_from_tag!(release.applied_commits.last.tag_name) }
  end

  attr_reader :release
  delegate :train, to: :release
end

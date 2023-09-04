class Triggers::ReleaseBackmerge
  include Loggable

  def self.call(commit)
    new(commit).call
  end

  def initialize(commit)
    @commit = commit
    @release = commit.release
  end

  def call
    return unless train.almost_trunk?
    return unless train.continuous_backmerge?

    res = release.with_lock do
      return GitHub::Result.new { } unless release.committable?
      Triggers::PatchPullRequest.create!(release, commit)
    end

    commit.update!(backmerge_failure: true) unless res.ok?
  end

  private

  attr_reader :release, :commit
  delegate :train, to: :release
end

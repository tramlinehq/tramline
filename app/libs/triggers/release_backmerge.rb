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

    release.with_lock do
      return unless release.committable?
      result = Triggers::PatchPullRequest.create!(release, commit)
      Rails.logger.debug "Patch Pull Request: result", result.value!
    end
  end

  private

  attr_reader :release, :commit
  delegate :train, to: :release
end

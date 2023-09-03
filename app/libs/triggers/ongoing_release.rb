class Triggers::OngoingRelease
  include Loggable

  def self.call(release)
    new(release).call
  end

  def initialize(release)
    @release = release
  end

  POST_RELEASE_HANDLERS = {
    "almost_trunk" => AlmostTrunk
  }

  def call
    return unless train.branching_strategy.in?(POST_RELEASE_HANDLERS.keys)
    return unless train.continuous_backmerge?

    release.with_lock do
      return unless release.committable?

      POST_RELEASE_HANDLERS[train.branching_strategy].call(release)
    end
  end

  private

  attr_reader :release
  delegate :train, to: :release
end

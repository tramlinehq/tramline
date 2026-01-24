class Coordinators::IncreaseStoreRollout
  def self.call(rollout)
    new(rollout).call
  end

  def initialize(rollout)
    @rollout = rollout
  end

  def call
    raise "release is not actionable" unless rollout.actionable?
    raise "rollout is not started" unless rollout.started?

    rollout.move_to_next_stage!
    raise rollout.errors.full_messages.to_sentence if rollout.errors?

    true
  end

  attr_reader :rollout
end

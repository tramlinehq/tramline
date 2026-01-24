class Coordinators::HaltStoreRollout
  def self.call(rollout)
    new(rollout).call
  end

  def initialize(rollout)
    @rollout = rollout
  end

  def call
    raise "release is not actionable" unless rollout.actionable?
    raise "rollout is not in a state that can be halted" unless rollout.may_halt?

    rollout.halt_release!
    raise rollout.errors.full_messages.to_sentence if rollout.errors?

    true
  end

  attr_reader :rollout
end

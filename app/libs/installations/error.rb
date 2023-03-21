class Installations::Error < StandardError
  attr_reader :reason

  def initialize(msg, reason: nil)
    @reason = reason
    super(msg)
  end
end

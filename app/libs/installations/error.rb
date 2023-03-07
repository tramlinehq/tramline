class Installations::Error < StandardError
  attr_reader :reason

  def initialize(reason = nil)
    @reason = reason
    super(@reason.to_s.humanize)
  end
end

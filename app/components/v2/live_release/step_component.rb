class V2::LiveRelease::StepComponent < ViewComponent::Base
  def initialize(frame:, title:)
    @frame = frame
    @title = title
  end

  attr_reader :frame, :title
end

class V2::LiveRelease::StepComponent < ViewComponent::Base
  def initialize(title:, frame:, control_content: false)
    @title = title
    @frame = frame
    @control_content = control_content
  end

  attr_reader :frame, :title, :control_content
end

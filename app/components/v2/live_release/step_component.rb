class V2::LiveRelease::StepComponent < ViewComponent::Base
  renders_many :sub_actions

  def initialize(title:, frame:, control_content: false, subtitle: nil)
    @title = title
    @subtitle = subtitle
    @frame = frame
    @control_content = control_content
  end

  attr_reader :frame, :title, :control_content, :subtitle
end

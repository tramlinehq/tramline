class V2::LiveRelease::StepComponent < ViewComponent::Base
  renders_many :sub_actions

  def initialize(title:, icon:, frame:, control_content: false, subtitle: nil)
    @title = title
    @subtitle = subtitle
    @frame = frame
    @icon = icon
    @control_content = control_content
  end

  attr_reader :frame, :title, :control_content, :subtitle, :icon
end

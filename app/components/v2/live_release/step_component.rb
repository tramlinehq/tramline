class V2::LiveRelease::StepComponent < ViewComponent::Base
  renders_many :sub_actions

  def initialize(title:, icon:, frame:, loader: true, subtitle: nil)
    @title = title
    @subtitle = subtitle
    @frame = frame
    @icon = icon
    @loader = loader
  end

  attr_reader :frame, :title, :loader, :subtitle, :icon

  def loader_class
    "with-turbo-frame-loader" if loader
  end
end

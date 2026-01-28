class EnhancedTurboFrameComponent < BaseComponent
  include Turbo::FramesHelper

  renders_one :loading_indicator, -> { LoadingIndicatorComponent.new(typewriter_only: true, turbo_frame: true) }

  def initialize(frame_id, classes: "", src: nil)
    @frame_id = frame_id
    @classes = classes
    @src = src
  end
end

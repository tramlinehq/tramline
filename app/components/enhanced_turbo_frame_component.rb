class EnhancedTurboFrameComponent < BaseComponent
  renders_one :loading_indicator, -> { LoadingIndicatorComponent.new(typewriter_only: true, turbo_frame: true) }

  def initialize(frame_id, classes: "")
    @frame_id = frame_id
    @classes = classes
  end
end

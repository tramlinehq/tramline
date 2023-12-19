# frozen_string_literal: true
class V2::EnhancedTurboFrameComponent < V2::BaseComponent
  renders_one :loading_indicator, V2::LoadingIndicatorComponent

  def initialize(frame_id, classes: "")
    @frame_id = frame_id
    @classes = classes
  end
end

class V2::LoadingIndicatorComponent < V2::BaseComponent
  def initialize(text: "Loading...", pulse: true, typewriter_only: false, skeleton_only: false, turbo_frame: false)
    raise ArgumentError, "Indicator can only be a skeleton or typewriter" if typewriter_only && skeleton_only
    @text = text
    @pulse = pulse
    @skeleton_only = skeleton_only
    @typewriter_only = typewriter_only
    @turbo_frame = turbo_frame
  end

  attr_reader :text

  def pulse
    "animate-pulse" if @pulse && !@typewriter_only && !@skeleton_only
  end

  PULSE_WRAPPER_CLASSES = "px-3 py-1 text-xs font-medium leading-none text-center text-blue-800 bg-blue-200 rounded-full dark:bg-blue-900 dark:text-blue-200"

  def pulse_wrapper_classes
    PULSE_WRAPPER_CLASSES + " #{pulse}"
  end

  def turbo_frame_loader
    "turbo-frame-loader" if @turbo_frame
  end
end

class V2::StatusIndicatorPillComponent < V2::BaseComponent
  def initialize(text:, status:)
    @text = text
    @status = status
  end

  attr_reader :text

  def background
    STATUS_COLOR_PALETTE[@status.to_sym].join(" ")
  end

  def pill
    PILL_STATUS_COLOR_PALETTE[@status.to_sym].join(" ")
  end
end

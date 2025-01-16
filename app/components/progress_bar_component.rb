class ProgressBarComponent < BaseComponent
  def initialize(percent:, label: false, status: :default)
    @percent = percent
    @label = label
    @status = status
  end

  attr_reader :label

  def fill
    "width: #{@percent}%;"
  end

  def perc
    "#{@percent}%"
  end

  def color
    PROGRESS_BAR_COLOR_PALETTE[@status]
  end
end

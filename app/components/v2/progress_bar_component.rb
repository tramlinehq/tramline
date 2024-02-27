class V2::ProgressBarComponent < ViewComponent::Base
  def initialize(percent:, label: false)
    @percent = percent
    @label = label
  end

  attr_reader :label

  def fill
    "width: #{@percent}%;"
  end

  def perc
    "#{@percent}%"
  end
end

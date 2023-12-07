# frozen_string_literal: true

class V2::ProgressBarComponent < ViewComponent::Base
  def initialize(percent:, label: false)
    @percent = percent
    @label = label
  end

  def fill
    "width: #{@percent}%;"
  end

  def perc
    "#{@percent}%" if @label
  end
end
